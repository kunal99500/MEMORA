import re
from pathlib import Path

from docx import Document
from pypdf import PdfReader


class DocumentReadError(ValueError):
    pass


def extract_document_sections(path: Path, file_type: str) -> list[tuple[str, str]]:
    try:
        if file_type == '.pdf':
            reader = PdfReader(str(path))
            if len(reader.pages) > 500:
                raise DocumentReadError('PDF documents may contain at most 500 pages.')
            return [
                (f'Page {index + 1}', text.strip())
                for index, page in enumerate(reader.pages)
                if (text := page.extract_text() or '').strip()
            ]
        if file_type == '.docx':
            document = Document(str(path))
            sections = [
                (f'Paragraph {index + 1}', paragraph.text.strip())
                for index, paragraph in enumerate(document.paragraphs)
                if paragraph.text.strip()
            ]
            for table_index, table in enumerate(document.tables, 1):
                rows = [
                    ' | '.join(cell.text.strip() for cell in row.cells).strip()
                    for row in table.rows
                ]
                table_text = '\n'.join(row for row in rows if row.strip())
                if table_text:
                    sections.append((f'Table {table_index}', table_text))
            return sections
    except DocumentReadError:
        raise
    except Exception as exc:
        raise DocumentReadError('The document could not be read.') from exc
    raise DocumentReadError('Only PDF and DOCX documents are supported.')


_STOP_WORDS = {
    'about', 'after', 'are', 'can', 'did', 'does', 'for', 'from', 'have',
    'how', 'into', 'is', 'me', 'my', 'of', 'on', 'show', 'tell', 'the',
    'this', 'to', 'was', 'were', 'what', 'when', 'where', 'which', 'who',
    'with', 'would', 'you', 'your',
}


def find_document_passages(
    sections: list[tuple[str, str]], query: str, limit: int = 3
) -> list[tuple[str, str]]:
    terms = {
        term.casefold()
        for term in re.findall(r'[\w@.-]{2,}', query, flags=re.UNICODE)
        if term.casefold() not in _STOP_WORDS
    }
    if not terms:
        return []

    matches: list[tuple[int, str, str]] = []
    for label, text in sections:
        for passage in re.split(r'(?<=[.!?])\s+|\n+', text):
            passage = passage.strip()
            if not passage:
                continue
            words = {
                term.casefold()
                for term in re.findall(r'[\w@.-]{2,}', passage, flags=re.UNICODE)
            }
            overlap = terms & words
            if overlap:
                score = sum(passage.casefold().count(term) for term in overlap)
                matches.append((score, label, passage))
    matches.sort(key=lambda item: item[0], reverse=True)
    return [(label, passage[:900]) for _, label, passage in matches[:limit]]
