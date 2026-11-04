"""Grounded Q&A over a workspace's stored visual memory (scene notes + observations).

Answers ONLY from stored memory, cites evidence tags that map back to real
Evidence rows, and returns their ids so the client can fetch the photos.
"""
from __future__ import annotations
import logging
import re
from sqlalchemy.orm import Session
from app.models.entities import Evidence, ObjectIdentity, Observation, SceneNote
from app.vision.muse import ask_memory

logger = logging.getLogger(__name__)


def _asks_for_visible_items(query: str) -> bool:
    text = query.casefold()
    asks_to_list = re.search(r"\b(?:what|which|list|show|name|identify|tell me)\b", text)
    asks_for_items = re.search(r"\b(?:objects?|items?|things?)\b", text)
    asks_what_is_visible = re.search(
        r"\b(?:what do you see|what can you see|what is visible|what(?:'s|’s| is) in)\b", text
    )
    mentions_visual_context = re.search(
        r"\b(?:image|photo|picture|scan|scene|room|space|there)\b", text
    )
    return bool(asks_to_list and mentions_visual_context
                and (asks_for_items or asks_what_is_visible))


def _where_target(query: str) -> str:
    match = re.search(
        r"\bwhere(?:'s|’s| is| are| can i find| did i put| did i leave)\s+(.+?)[?.!]*$",
        query.casefold().strip(),
    )
    if not match:
        return ""
    target = match.group(1)
    target = re.sub(r"\b(?:the|a|an|my|our|this|that|please)\b", " ", target)
    return re.sub(r"\s+", " ", target).strip()


_LOCATION_ALIASES = {
    "box": ("box", "boxes", "tote", "totes", "bin", "bins", "container", "containers", "crate", "crates"),
    "green": ("green", "lime green", "lime-green"),
    "red": ("red",),
    "blue": ("blue",),
    "black": ("black",),
    "white": ("white",),
    "gardening": ("gardening", "garden"),
    "tools": ("tools", "tool", "equipment"),
}

_CONTAINER_ALIASES = {
    "box": ("box", "boxes", "tote", "totes", "bin", "bins", "container", "containers"),
}


def _asks_for_container_contents(query: str) -> bool:
    text = query.casefold()
    asks_what = re.search(r"\bwhat(?:'s|’s| is| are)\b", text)
    asks_inside = re.search(r"\b(?:in|inside|within)\b", text)
    mentions_container = re.search(
        r"\b(?:box(?:es)?|totes?|bins?|containers?)\b", text
    )
    return bool(asks_what and asks_inside and mentions_container)


def _container_contents_fallback(query: str, scenes: list[SceneNote]) -> dict:
    text = query.casefold()
    aliases = [
        alias
        for key, values in _CONTAINER_ALIASES.items()
        if re.search(rf"\b{key}(?:es)?\b", text)
        for alias in values
    ]
    aliases.extend(
        color for color in ("green", "red", "blue", "black", "white")
        if re.search(rf"\b{color}\b", text)
    )
    matching_scene = next(
        (
            scene for scene in scenes
            if any(alias in (scene.text or "").casefold().replace("-", " ")
                   for alias in aliases)
        ),
        None,
    )
    return {
        "answer": "The saved scans don't show what's inside the boxes, so their contents aren't recorded.",
        "evidence": [matching_scene.evidence_id] if matching_scene and matching_scene.evidence_id else [],
        "confidence": 0.0,
        "language": "en",
    }


def _find_location_evidence(query: str, scenes: list[SceneNote]) -> dict | None:
    target = _where_target(query)
    if not target:
        return None

    terms = [term for term in target.split() if len(term) > 1]
    if not terms:
        return None

    groups = [
        _LOCATION_ALIASES.get(term, (term,))
        for term in terms
    ]
    best: tuple[float, str, str] | None = None
    for scene in scenes:
        for sentence in re.split(r"(?<=[.!?])\s+", scene.text or ""):
            normalized = sentence.casefold().replace("-", " ")
            matched = sum(
                any(alias.replace("-", " ") in normalized for alias in aliases)
                for aliases in groups
            )
            if not matched:
                continue
            score = matched / len(groups)
            if best is None or score > best[0]:
                best = (score, sentence.strip(), scene.evidence_id or "")

    if best is None or best[0] < 0.5:
        return None
    sentence = best[1]
    answer = sentence if sentence.endswith((".", "!", "?")) else sentence + "."
    language = ""
    try:
        translated = ask_memory(
            f"SCENE [E1]: {answer}",
            query,
        )
        translated_answer = str(translated.get("answer") or "").strip()
        if (
            translated_answer
            and translated_answer
            != "I couldn't generate a reply this time. Please try asking again."
        ):
            answer = translated_answer
        language = str(translated.get("language") or "")
    except Exception:
        logger.exception("Could not translate a grounded scene answer")
    return {
        "answer": answer,
        "evidence": [best[2]] if best[2] else [],
        "confidence": round(0.65 + 0.3 * best[0], 2),
        "language": language,
    }


def _original_frame_evidence_id(db: Session, evidence_id: str) -> str:
    evidence = db.get(Evidence, evidence_id)
    if not evidence or not evidence.frame_id:
        return evidence_id
    original = (db.query(Evidence)
                .filter_by(frame_id=evidence.frame_id, source_type="original_frame")
                .first())
    return original.id if original else evidence_id


def _find_saved_object_location(
    db: Session,
    query: str,
    objects: list[ObjectIdentity],
    latest_by_object: dict[str, Observation],
) -> dict | None:
    target = _where_target(query)
    target_terms = set(re.findall(r"[a-z0-9]+", target))
    if not target_terms:
        return None

    best: tuple[float, ObjectIdentity, Observation] | None = None
    for obj in objects:
        observation = latest_by_object.get(obj.id)
        if not observation or not (observation.location_text or "").strip():
            continue
        label_terms = set(re.findall(r"[a-z0-9]+", obj.canonical_label.casefold()))
        matched = len(target_terms & label_terms)
        score = matched / len(target_terms)
        if matched and (best is None or score > best[0]):
            best = (score, obj, observation)

    if best is None or best[0] < 0.6:
        return None

    _, obj, observation = best
    label = obj.canonical_label.strip()
    location = re.sub(
        r"\b(on|in|under|beside|near)\s+person's\b",
        r"\1 the person's",
        observation.location_text.strip(),
        flags=re.IGNORECASE,
    )
    article = "an" if label[:1].casefold() in "aeiou" else "a"
    answer = f"I last saw {article} {label} {location}."
    evidence_ids = (
        [_original_frame_evidence_id(db, observation.evidence_id)]
        if observation.evidence_id else []
    )
    confidence_data = observation.confidence or {}
    confidence = confidence_data.get("detection", 0.8)
    if not isinstance(confidence, (int, float)):
        confidence = 0.8
    return {
        "answer": answer,
        "evidence": evidence_ids,
        "confidence": max(0.0, min(1.0, float(confidence))),
        "language": "en",
    }


def answer_question(db: Session, workspace_id: str, query: str) -> dict:
    scenes = db.query(SceneNote).filter_by(workspace_id=workspace_id).all()
    objects = (db.query(ObjectIdentity).filter_by(workspace_id=workspace_id)
               .order_by(ObjectIdentity.created_at.desc()).all())
    object_ids = [obj.id for obj in objects]
    latest_by_object = {}
    if object_ids:
        observations = (db.query(Observation)
                       .filter(Observation.object_id.in_(object_ids))
                       .order_by(Observation.observed_at.desc()).all())
        for observation in observations:
            latest_by_object.setdefault(observation.object_id, observation)

    if _asks_for_visible_items(query) and objects:
        seen_labels: set[str] = set()
        labels: list[str] = []
        evidence_ids: list[str] = []
        frame_labels: dict[str, list[str]] = {}
        frame_language_tags: dict[str, str] = {}
        confidences: list[float] = []
        for obj in objects:
            observation = latest_by_object.get(obj.id)
            label = obj.canonical_label.strip()
            if not observation or not label or label.casefold() in seen_labels:
                continue
            seen_labels.add(label.casefold())
            labels.append(label)
            if observation.evidence_id:
                evidence_id = _original_frame_evidence_id(db, observation.evidence_id)
                if evidence_id not in evidence_ids:
                    evidence_ids.append(evidence_id)
                frame_labels.setdefault(evidence_id, []).append(label)
            detection_confidence = (observation.confidence or {}).get("detection")
            if isinstance(detection_confidence, (int, float)):
                confidences.append(max(0.0, min(1.0, float(detection_confidence))))
        if labels:
            frame_language_tags = {
                evidence_id: f"E{index}"
                for index, evidence_id in enumerate(frame_labels, 1)
            }
            list_context = "\n".join(
                f"VISIBLE ITEMS [{frame_language_tags[evidence_id]}]: {', '.join(frame_items)}"
                for evidence_id, frame_items in frame_labels.items()
            )
            answer = "I found these items in your scans: " + ", ".join(labels) + "."
            response_evidence = evidence_ids
            language = ""
            try:
                localized = ask_memory(list_context, query)
                localized_answer = str(localized.get("answer") or "").strip()
                if localized_answer:
                    answer = localized_answer
                language = str(localized.get("language") or "")
                tagged_evidence = [
                    evidence_id
                    for tag in (localized.get("evidence_tags") or [])
                    if (evidence_id := next(
                        (key for key, value in frame_language_tags.items()
                         if value == str(tag).strip()), None
                    ))
                ]
                if tagged_evidence:
                    response_evidence = list(dict.fromkeys(tagged_evidence))
            except Exception:
                logger.exception("Could not localize a visible-item answer")
            return {
                "answer": answer,
                "evidence": response_evidence,
                "confidence": sum(confidences) / len(confidences) if confidences else 0.0,
                "language": language,
            }

    location_answer = _find_saved_object_location(
        db, query, objects, latest_by_object
    )
    if location_answer is not None:
        return location_answer

    location_answer = _find_location_evidence(query, scenes)
    if location_answer is not None:
        return location_answer

    lines: list[str] = []
    ev_map: dict[str, str] = {}
    n = 0

    # Full scene descriptions first — richest detail for fine-grained questions.
    for sc in scenes:
        n += 1
        tag = f"E{n}"
        if sc.evidence_id:
            ev_map[tag] = sc.evidence_id
        lines.append(f"SCENE [{tag}]: {sc.text}")

    for o in objects:
        ob = latest_by_object.get(o.id)
        n += 1
        tag = f"E{n}"
        if ob and ob.evidence_id:
            ev_map[tag] = _original_frame_evidence_id(db, ob.evidence_id)
        loc = ob.location_text if ob else ''
        cond = ob.condition_text if ob else ''
        lines.append(f"OBJECT [{tag}] {o.canonical_label}: location='{loc}', condition='{cond}'")

    context = "\n".join(lines)
    if not context.strip():
        try:
            data = ask_memory("NO SAVED MEMORY", query)
            answer = str(data.get("answer") or "").strip()
            return {
                "answer": answer or "I have no memory recorded for this workspace yet.",
                "evidence": [],
                "confidence": float(data.get("confidence", 0.0) or 0.0),
                "language": str(data.get("language") or ""),
            }
        except Exception:
            logger.exception("Could not localize the empty-workspace answer")
            return {"answer": "I have no memory recorded for this workspace yet.",
                    "evidence": [], "confidence": 0.0}

    try:
        data = ask_memory(context, query)
    except Exception as exc:
        return {"answer": "I couldn't reach the reasoning model to answer that right now.",
                "evidence": [], "confidence": 0.0, "error": str(exc)}

    ev_ids: list[str] = []
    for t in data.get("evidence_tags", []) or []:
        eid = ev_map.get(str(t).strip())
        if eid and eid not in ev_ids:
            ev_ids.append(eid)
    answer = str(data.get("answer") or "").strip()
    if (
        answer == "I couldn't generate a reply this time. Please try asking again."
        and _asks_for_container_contents(query)
    ):
        return _container_contents_fallback(query, scenes)
    if not answer:
        answer = "I couldn't generate a reply this time. Please try asking again."
    return {"answer": answer,
            "evidence": ev_ids,
            "confidence": float(data.get("confidence", 0.0) or 0.0),
            "language": str(data.get("language") or "")}
