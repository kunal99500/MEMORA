import base64,json,re
import logging
from pathlib import Path
from openai import OpenAI
from app.core.config import get_settings
logger = logging.getLogger(__name__)
SYSTEM='''You are MEMORA visual observation extraction. Return only JSON with keys scene and objects. scene: one concise but specific paragraph describing notable visible items and their locations. Each object: label, category, location, condition, attributes, bbox (normalized top-left xywh from 0 to 1), confidence. Only state visible evidence. Do not infer hidden contents, actions, brand/model, or physical identity. Use unknown/null when uncertain.'''
def analyze_image(path:str,context:dict|None=None)->dict:
    s=get_settings()
    if not s.meta_api_key:raise RuntimeError('META_API_KEY is not configured')
    ext=Path(path).suffix.lower();mime='image/png' if ext=='.png' else 'image/jpeg'
    b64=base64.b64encode(Path(path).read_bytes()).decode()
    client=OpenAI(base_url=s.meta_api_base,api_key=s.meta_api_key,timeout=90)
    r=client.chat.completions.create(model=s.muse_spark_model,temperature=0,messages=[
        {'role':'system','content':SYSTEM},{'role':'user','content':[{'type':'text','text':f'Context: {json.dumps(context or {})}'},{'type':'image_url','image_url':{'url':f'data:{mime};base64,{b64}'}}]}])
    raw=(r.choices[0].message.content or '{}').strip();raw=re.sub(r'^```(?:json)?|```$','',raw,flags=re.I).strip()
    data=json.loads(raw)
    if not isinstance(data,dict) or not isinstance(data.get('objects',[]),list):raise ValueError('Invalid vision response schema')
    return data


ASK_SYSTEM='''You are MEMORA, the memory of a physical space. Answer the user's question using ONLY the MEMORY provided. Respond in the same language as the user's question; translate memory facts as needed, but never change their meaning. If memory does not contain the answer, say so in that same language and never invent. Never return an empty answer. Cite evidence tags (like E1, E3) for every fact used. Keep the answer concise. Respond ONLY as JSON: {"answer": "...", "evidence_tags": ["E1"], "confidence": 0.0, "language": "BCP-47 language tag"}'''


def _parse_ask_response(raw: str) -> dict | None:
    raw = re.sub(r'^```(?:json)?|```$', '', raw.strip(), flags=re.I).strip()
    if not raw:
        return None
    try:
        data = json.loads(raw)
    except json.JSONDecodeError:
        return {
            'answer': raw[:800],
            'evidence_tags': [],
            'confidence': 0.0,
        }
    if not isinstance(data, dict):
        return None
    answer = str(data.get('answer') or '').strip()
    if not answer:
        return None
    data['answer'] = answer
    return data


def ask_memory(context:str,question:str)->dict:
    s=get_settings()
    if not s.meta_api_key:raise RuntimeError('META_API_KEY is not configured')
    client=OpenAI(base_url=s.meta_api_base,api_key=s.meta_api_key,timeout=90)
    messages = [
        {'role':'system','content':ASK_SYSTEM},
        {'role':'user','content':f'MEMORY:\n{context}\n\nQUESTION: {question}'},
    ]
    response = client.chat.completions.create(
        model=s.muse_spark_model,
        temperature=0,
        messages=messages,
        max_tokens=500,
    )
    choice = response.choices[0] if response.choices else None
    message = choice.message if choice else None
    data = _parse_ask_response(str(getattr(message, 'content', None) or ''))
    if data:
        return data

    logger.warning(
        "Reasoning model returned an empty or invalid answer; retrying once "
        "(finish_reason=%s, refusal=%s)",
        getattr(choice, 'finish_reason', None),
        bool(getattr(message, 'refusal', None)),
    )
    retry_messages = [
        {
            'role': 'system',
            'content': ASK_SYSTEM + ' Your previous response was empty or invalid. '
            'Return a complete, concise JSON answer now.',
        },
        messages[1],
    ]
    retry = client.chat.completions.create(
        model=s.muse_spark_model,
        temperature=0,
        messages=retry_messages,
        max_tokens=500,
    )
    retry_choice = retry.choices[0] if retry.choices else None
    retry_message = retry_choice.message if retry_choice else None
    data = _parse_ask_response(str(getattr(retry_message, 'content', None) or ''))
    if data:
        return data

    logger.error(
        "Reasoning model returned no usable answer after retry "
        "(finish_reason=%s, refusal=%s)",
        getattr(retry_choice, 'finish_reason', None),
        bool(getattr(retry_message, 'refusal', None)),
    )
    return {
        'answer': "I couldn't generate a reply this time. Please try asking again.",
        'evidence_tags': [],
        'confidence': 0.0,
    }
