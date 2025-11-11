#!/usr/bin/env python3
"""
DOCX to HTML Converter
Converts Microsoft Word documents to clean HTML with configurable formatting rules.
"""

import sys
import json
import argparse
import re
from pathlib import Path
from typing import List, Dict, Any, Optional
from docx import Document
from docx.table import Table
from docx.text.paragraph import Paragraph
from docx.oxml.text.paragraph import CT_P
from docx.oxml.table import CT_Tbl
from lxml import etree


class DocxToHtmlConverter:
    """Converts DOCX files to HTML with configurable formatting."""

    def __init__(self, config: Dict[str, Any]):
        """
        Initialize converter with configuration.

        Args:
            config: Configuration dictionary from JSON file
        """
        self.config = config
        self.output_config = config.get('output', {})
        self.special_chars = config.get('special_characters', {})
        self.replacements = config.get('replacements', [])
        self.quote_detection = config.get('quote_detection', {})

    def convert_docx_to_html(self, docx_path: str) -> str:
        """
        Convert a DOCX file to HTML.

        Args:
            docx_path: Path to the DOCX file

        Returns:
            HTML string
        """
        doc = Document(docx_path)
        html_parts = []

        # Track list items for grouping
        current_list_items = []
        current_list_type = None  # 'bullet' or 'number'

        # Process document elements in order
        for element in doc.element.body:
            if isinstance(element, CT_P):
                # Paragraph
                paragraph = Paragraph(element, doc)
                list_info = self._get_list_info(paragraph)

                if list_info:
                    # This is a list item - store as (level, type, text) tuple
                    list_type, level, list_text = list_info

                    # Add to current list items (with level and type information)
                    if current_list_type is None:
                        # Starting a new list
                        current_list_type = list_type

                    current_list_items.append((level, list_type, list_text))
                else:
                    # Not a list item - close any open list first
                    if current_list_items:
                        html_parts.append(self._create_list_html(current_list_items, current_list_type))
                        current_list_items = []
                        current_list_type = None

                    # Process as regular paragraph
                    html = self._convert_paragraph(paragraph)
                    if html:
                        html_parts.append(html)

            elif isinstance(element, CT_Tbl):
                # Close any open list first
                if current_list_items:
                    html_parts.append(self._create_list_html(current_list_items, current_list_type))
                    current_list_items = []
                    current_list_type = None

                # Table
                table = Table(element, doc)
                html = self._convert_table(table)
                if html:
                    html_parts.append(html)

        # Close any remaining open list
        if current_list_items:
            html_parts.append(self._create_list_html(current_list_items, current_list_type))

        # Join all HTML parts
        full_html = '\n'.join(html_parts)

        # Apply special character transformations
        full_html = self._apply_special_characters(full_html)

        # Apply custom replacements
        full_html = self._apply_replacements(full_html)

        return full_html

    def _convert_paragraph(self, paragraph: Paragraph) -> str:
        """
        Convert a paragraph to HTML.

        Args:
            paragraph: Docx paragraph object

        Returns:
            HTML string
        """
        text = paragraph.text.strip()
        if not text:
            return ''

        # Check if it's a heading
        if paragraph.style.name.startswith('Heading'):
            tag = self.output_config.get('heading_tag', 'h3')
            return f'<{tag}>{self._escape_html(text)}</{tag}>'

        # Regular paragraph
        tag = self.output_config.get('paragraph_tag', 'p')

        # Process runs to handle inline formatting if needed
        html_text = self._process_runs(paragraph)

        # Check for quote detection
        if self.quote_detection.get('enabled', False):
            threshold = self.quote_detection.get('threshold', 3)
            if self._count_quotes(text) >= threshold:
                wrap_tag = self.quote_detection.get('wrap_tag', 'blockquote')
                opening_tag, closing_tag = self._parse_wrap_tag(wrap_tag)
                return f'{opening_tag}<{tag}>{html_text}</{tag}>{closing_tag}'

        return f'<{tag}>{html_text}</{tag}>'

    def _get_list_info(self, paragraph: Paragraph) -> Optional[tuple]:
        """
        Check if paragraph is a list item and return its type, level, and text.

        Args:
            paragraph: Docx paragraph object

        Returns:
            Tuple of (list_type, level, text) or None if not a list item
            list_type is either 'bullet' or 'number'
            level is the indentation level (0-based)
        """
        # Check for numbering in the paragraph's XML properties
        p_element = paragraph._element
        pPr = p_element.find('.//{http://schemas.openxmlformats.org/wordprocessingml/2006/main}pPr')

        if pPr is not None:
            numPr = pPr.find('.//{http://schemas.openxmlformats.org/wordprocessingml/2006/main}numPr')
            if numPr is not None:
                # This paragraph is part of a numbered/bulleted list
                ilvl_element = numPr.find('.//{http://schemas.openxmlformats.org/wordprocessingml/2006/main}ilvl')
                numId_element = numPr.find('.//{http://schemas.openxmlformats.org/wordprocessingml/2006/main}numId')

                if numId_element is not None:
                    text = self._process_runs(paragraph)
                    level = int(ilvl_element.get('{http://schemas.openxmlformats.org/wordprocessingml/2006/main}val', '0')) if ilvl_element is not None else 0

                    # Try to determine if it's bullet or numbered
                    # This is a simplified approach - you could enhance it by reading the numbering.xml
                    list_type = 'bullet'  # Default to bullet

                    return (list_type, level, text)

        # Fallback: Check if paragraph has a list style
        style_name = paragraph.style.name.lower()

        # Check for list-related styles
        if 'list bullet' in style_name or paragraph.style.name.startswith('List Bullet'):
            text = self._process_runs(paragraph)
            # Try to extract level from style name (e.g., "List Bullet 2")
            level = 0
            level_match = re.search(r'\d+$', paragraph.style.name)
            if level_match:
                level = int(level_match.group()) - 1  # Convert to 0-based
            return ('bullet', level, text)
        elif 'list number' in style_name or paragraph.style.name.startswith('List Number'):
            text = self._process_runs(paragraph)
            level = 0
            level_match = re.search(r'\d+$', paragraph.style.name)
            if level_match:
                level = int(level_match.group()) - 1
            return ('number', level, text)

        return None

    def _create_list_html(self, items: List[tuple], list_type: str) -> str:
        """
        Create HTML list from list items with support for nesting.

        Args:
            items: List of tuples (level, list_type, text) where level is 0-based indentation
            list_type: 'bullet' or 'number' (currently not used as type is per-item)

        Returns:
            HTML string for the list with nested structures
        """
        if not items:
            return ''

        # Find the minimum level to use as base level
        min_level = min(item[0] for item in items)

        # Build from the minimum level found
        html, _ = self._build_nested_list(items, 0, min_level)
        return html

    def _build_nested_list(self, items: List[tuple], start_index: int, current_level: int) -> tuple:
        """
        Recursively build nested HTML lists.

        Args:
            items: List of tuples (level, list_type, text)
            start_index: Current index in items list
            current_level: Current nesting level we're building for

        Returns:
            Tuple of (html_string, next_index)
        """
        if start_index >= len(items):
            return ('', start_index)

        html_parts = []
        i = start_index
        current_list_type = None
        list_started = False

        while i < len(items):
            level, item_type, text = items[i]

            if level < current_level:
                # Going back up a level - close current list and return
                if list_started and current_list_type:
                    tag = 'ul' if current_list_type == 'bullet' else 'ol'
                    html_parts.append(f'</{tag}>')
                return ('\n'.join(html_parts), i)

            elif level == current_level:
                # Same level - add list item
                if not list_started:
                    # Start the list
                    current_list_type = item_type
                    tag = 'ul' if current_list_type == 'bullet' else 'ol'
                    html_parts.append(f'<{tag}>')
                    list_started = True
                elif current_list_type != item_type:
                    # Different list type at same level - close and start new list
                    old_tag = 'ul' if current_list_type == 'bullet' else 'ol'
                    html_parts.append(f'</{old_tag}>')
                    current_list_type = item_type
                    tag = 'ul' if current_list_type == 'bullet' else 'ol'
                    html_parts.append(f'<{tag}>')

                # Check if next item is nested (deeper level)
                if i + 1 < len(items) and items[i + 1][0] > level:
                    # This item will have nested content
                    html_parts.append(f'  <li>{text}')
                    # Build nested list
                    nested_html, next_i = self._build_nested_list(items, i + 1, items[i + 1][0])
                    # Indent nested list
                    indented_nested = '\n'.join('    ' + line for line in nested_html.split('\n'))
                    html_parts.append(indented_nested)
                    html_parts.append('  </li>')
                    i = next_i
                else:
                    # Simple list item
                    html_parts.append(f'  <li>{text}</li>')
                    i += 1

            else:  # level > current_level
                # This shouldn't happen if we call the function correctly
                # Skip this item and let the parent level handle it
                break

        # Close the list if it was started
        if list_started and current_list_type:
            tag = 'ul' if current_list_type == 'bullet' else 'ol'
            html_parts.append(f'</{tag}>')

        return ('\n'.join(html_parts), i)

    def _process_runs(self, paragraph: Paragraph) -> str:
        """
        Process paragraph runs to preserve inline formatting and hyperlinks.
        Consolidates consecutive runs with identical formatting to avoid nested tags.

        Args:
            paragraph: Docx paragraph object

        Returns:
            HTML string with inline formatting and hyperlinks
        """
        # First, extract hyperlinks from the paragraph
        hyperlinks = self._extract_hyperlinks(paragraph)

        result = []
        current_hyperlink = None
        hyperlink_text = []
        processed_hyperlinks = set()  # Track which hyperlinks we've processed

        # Track formatting groups to consolidate consecutive runs
        current_group = {
            'text': [],
            'bold': None,
            'italic': None,
            'underline': None,
            'hyperlink': None
        }

        def flush_group():
            """Apply formatting tags to accumulated text group and add to result."""
            if not current_group['text']:
                return

            # Combine all text in the group
            combined_text = ''.join(current_group['text'])

            # Apply formatting tags in order (bold -> italic -> underline)
            formatted_text = combined_text
            if current_group['underline']:
                formatted_text = f'<u>{formatted_text}</u>'
            if current_group['italic']:
                formatted_text = f'<em>{formatted_text}</em>'
            if current_group['bold']:
                formatted_text = f'<strong>{formatted_text}</strong>'

            # Add to appropriate collection
            if current_group['hyperlink']:
                hyperlink_text.append(formatted_text)
            else:
                result.append(formatted_text)

            # Reset group
            current_group['text'] = []

        for run in paragraph.runs:
            text = run.text

            # Check if this run is part of a hyperlink (even if text is empty)
            run_hyperlink = None
            for link_id, link_url, link_runs, link_text in hyperlinks:
                if run._element in link_runs:
                    run_hyperlink = (link_id, link_url, link_text)
                    processed_hyperlinks.add(link_id)  # Mark as processed
                    break

            # Skip empty runs that aren't part of a hyperlink
            if not text and not run_hyperlink:
                continue

            # If we're starting a new hyperlink
            if run_hyperlink and run_hyperlink != current_hyperlink:
                # Flush current group
                flush_group()

                # Close previous hyperlink if any
                if current_hyperlink:
                    if hyperlink_text:
                        combined_text = ''.join(hyperlink_text)
                        result.append(self._format_link(current_hyperlink[1], combined_text))
                        hyperlink_text = []
                    else:
                        # Empty link text - use fallback text from hyperlink element
                        fallback_text = current_hyperlink[2] if len(current_hyperlink) > 2 and current_hyperlink[2] else current_hyperlink[1]
                        result.append(self._format_link(current_hyperlink[1], fallback_text))
                        hyperlink_text = []

                current_hyperlink = run_hyperlink

            # If we're ending a hyperlink
            elif not run_hyperlink and current_hyperlink:
                # Flush current group
                flush_group()

                # Close the hyperlink
                if hyperlink_text:
                    combined_text = ''.join(hyperlink_text)
                    result.append(self._format_link(current_hyperlink[1], combined_text))
                    hyperlink_text = []
                else:
                    # Empty link text - use fallback text from hyperlink element
                    fallback_text = current_hyperlink[2] if len(current_hyperlink) > 2 and current_hyperlink[2] else current_hyperlink[1]
                    result.append(self._format_link(current_hyperlink[1], fallback_text))
                    hyperlink_text = []
                current_hyperlink = None

            # Escape the text (use fallback if empty and in hyperlink)
            if not text and run_hyperlink:
                # Empty run in hyperlink - this is the case we're fixing!
                # Don't add anything to the group, the hyperlink will be output with its fallback text
                escaped_text = ''
            else:
                escaped_text = self._escape_html(text)

            # Determine formatting signature for this run
            run_bold = bool(run.bold)
            run_italic = bool(run.italic)
            run_underline = bool(run.underline) and not run_hyperlink

            # Check if formatting matches current group
            formatting_matches = (
                current_group['bold'] == run_bold and
                current_group['italic'] == run_italic and
                current_group['underline'] == run_underline and
                current_group['hyperlink'] == run_hyperlink
            )

            # If formatting differs or this is the first run, flush and start new group
            if not formatting_matches and current_group['text']:
                flush_group()

            # Update group formatting (for first run or after flush)
            if not current_group['text']:
                current_group['bold'] = run_bold
                current_group['italic'] = run_italic
                current_group['underline'] = run_underline
                current_group['hyperlink'] = run_hyperlink

            # Add text to current group
            current_group['text'].append(escaped_text)

        # Flush any remaining group
        flush_group()

        # Close any remaining hyperlink
        if current_hyperlink:
            if hyperlink_text:
                combined_text = ''.join(hyperlink_text)
                result.append(self._format_link(current_hyperlink[1], combined_text))
            else:
                # Empty link text - use fallback text from hyperlink element
                fallback_text = current_hyperlink[2] if len(current_hyperlink) > 2 and current_hyperlink[2] else current_hyperlink[1]
                result.append(self._format_link(current_hyperlink[1], fallback_text))

        # Output any hyperlinks that weren't processed during run iteration
        # This handles links whose runs aren't in paragraph.runs (python-docx limitation)
        # Note: These will be appended to end of paragraph - Word doc structure issue
        for link_id, link_url, link_runs, link_text in hyperlinks:
            if link_id not in processed_hyperlinks and link_text:
                result.append(' ')  # Add space before unprocessed link
                result.append(self._format_link(link_url, link_text))

        return ''.join(result)

    def _format_link(self, url: str, text: str) -> str:
        """
        Format a hyperlink as a basic anchor tag.

        Args:
            url: The link URL
            text: The link text

        Returns:
            Formatted <a> tag HTML string
        """
        return f'<a href="{url}">{text}</a>'

    def _extract_hyperlinks(self, paragraph: Paragraph) -> List[tuple]:
        """
        Extract hyperlinks from a paragraph, supporting both hyperlink elements and field codes.

        Args:
            paragraph: Docx paragraph object

        Returns:
            List of tuples (hyperlink_id, url, list_of_run_elements)
        """
        hyperlinks = []

        # Get the paragraph element
        p_element = paragraph._element

        # Method 1: Standard hyperlink elements
        hyperlink_elements = p_element.findall('.//{http://schemas.openxmlformats.org/wordprocessingml/2006/main}hyperlink')

        for idx, hyperlink in enumerate(hyperlink_elements):
            r_id = hyperlink.get('{http://schemas.openxmlformats.org/officeDocument/2006/relationships}id')
            anchor = hyperlink.get('{http://schemas.openxmlformats.org/wordprocessingml/2006/main}anchor')

            url = None
            if r_id:
                try:
                    url = paragraph.part.rels[r_id].target_ref
                except:
                    url = None

            if not url and anchor:
                url = f'#{anchor}'

            if url:
                run_elements = hyperlink.findall('.//{http://schemas.openxmlformats.org/wordprocessingml/2006/main}r')
                link_id = f'{r_id or anchor}_{idx}'
                # Extract text from hyperlink element as fallback
                link_text = hyperlink.text or ''
                hyperlinks.append((link_id, url, run_elements, link_text))

        # Method 2: Field codes (HYPERLINK fields)
        # Look for HYPERLINK field codes in the paragraph
        field_hyperlinks = self._extract_field_hyperlinks(paragraph)
        hyperlinks.extend(field_hyperlinks)

        return hyperlinks

    def _extract_field_hyperlinks(self, paragraph: Paragraph) -> List[tuple]:
        """
        Extract hyperlinks from HYPERLINK field codes.

        Args:
            paragraph: Docx paragraph object

        Returns:
            List of tuples (hyperlink_id, url, list_of_run_elements)
        """
        hyperlinks = []
        p_element = paragraph._element

        # Get all runs in the paragraph
        all_runs = p_element.findall('.//{http://schemas.openxmlformats.org/wordprocessingml/2006/main}r')

        i = 0
        field_idx = 0
        while i < len(all_runs):
            run = all_runs[i]

            # Check if this run contains a field begin character
            fld_char = run.find('.//{http://schemas.openxmlformats.org/wordprocessingml/2006/main}fldChar')

            if fld_char is not None and fld_char.get('{http://schemas.openxmlformats.org/wordprocessingml/2006/main}fldCharType') == 'begin':
                # Found the start of a field - look for the instrText in the next runs
                url = None
                link_runs = []
                j = i + 1

                # Look for the HYPERLINK instruction
                while j < len(all_runs):
                    instr_run = all_runs[j]
                    instr_text_elem = instr_run.find('.//{http://schemas.openxmlformats.org/wordprocessingml/2006/main}instrText')

                    if instr_text_elem is not None and instr_text_elem.text:
                        instr_text = instr_text_elem.text.strip()
                        # Parse HYPERLINK "url" format
                        if instr_text.startswith('HYPERLINK'):
                            # Extract URL from: HYPERLINK "url" or HYPERLINK "url" \o "tooltip"
                            match = re.search(r'HYPERLINK\s+"([^"]+)"', instr_text)
                            if match:
                                url = match.group(1)
                            break

                    # Check for separator or end
                    fld_char_check = instr_run.find('.//{http://schemas.openxmlformats.org/wordprocessingml/2006/main}fldChar')
                    if fld_char_check is not None:
                        fld_type = fld_char_check.get('{http://schemas.openxmlformats.org/wordprocessingml/2006/main}fldCharType')
                        if fld_type in ('separate', 'end'):
                            break

                    j += 1

                # Now find the actual link text (between 'separate' and 'end')
                if url:
                    # Continue from where we left off to find the separator
                    while j < len(all_runs):
                        sep_run = all_runs[j]
                        fld_char_sep = sep_run.find('.//{http://schemas.openxmlformats.org/wordprocessingml/2006/main}fldChar')

                        if fld_char_sep is not None and fld_char_sep.get('{http://schemas.openxmlformats.org/wordprocessingml/2006/main}fldCharType') == 'separate':
                            j += 1
                            break
                        j += 1

                    # Collect runs until we hit the 'end' field character
                    while j < len(all_runs):
                        text_run = all_runs[j]
                        fld_char_end = text_run.find('.//{http://schemas.openxmlformats.org/wordprocessingml/2006/main}fldChar')

                        if fld_char_end is not None and fld_char_end.get('{http://schemas.openxmlformats.org/wordprocessingml/2006/main}fldCharType') == 'end':
                            # Found the end of the field
                            break

                        # This run is part of the link text
                        link_runs.append(text_run)
                        j += 1

                    if link_runs:
                        link_id = f'field_{field_idx}'
                        # Extract text from link runs
                        link_text = ''
                        for r in link_runs:
                            t_elems = r.findall('.//{http://schemas.openxmlformats.org/wordprocessingml/2006/main}t')
                            link_text += ''.join([t.text for t in t_elems if t.text])
                        hyperlinks.append((link_id, url, link_runs, link_text))
                        field_idx += 1

                    # Continue from after the field
                    i = j + 1
                    continue

            i += 1

        return hyperlinks

    def _convert_table(self, table: Table) -> str:
        """
        Convert a table to HTML with thead and tbody.

        Args:
            table: Docx table object

        Returns:
            HTML string
        """
        if not table.rows:
            return ''

        html_parts = ['<table>']

        # First row as header
        if len(table.rows) > 0:
            html_parts.append('  <thead>')
            html_parts.append('    <tr>')

            header_row = table.rows[0]
            for cell in header_row.cells:
                cell_text = self._escape_html(cell.text.strip())
                html_parts.append(f'      <th>{cell_text}</th>')

            html_parts.append('    </tr>')
            html_parts.append('  </thead>')

        # Rest of rows as body
        if len(table.rows) > 1:
            html_parts.append('  <tbody>')

            for row in table.rows[1:]:
                html_parts.append('    <tr>')

                for cell in row.cells:
                    cell_text = self._escape_html(cell.text.strip())
                    html_parts.append(f'      <td>{cell_text}</td>')

                html_parts.append('    </tr>')

            html_parts.append('  </tbody>')

        html_parts.append('</table>')

        return '\n'.join(html_parts)

    def _apply_special_characters(self, html: str) -> str:
        """
        Apply special character transformations based on configuration.

        Args:
            html: HTML string

        Returns:
            Transformed HTML string
        """
        # Handle special characters from configuration
        # Support both old dict format and new list format for backwards compatibility
        if isinstance(self.special_chars, dict):
            # Old format: {copyright_symbol: {enabled, wrap_tag}, ...}
            # Convert to list format for processing
            char_configs = []

            # Handle legacy copyright_symbol
            if 'copyright_symbol' in self.special_chars:
                config = self.special_chars['copyright_symbol']
                if config.get('enabled', True):
                    char_configs.append({
                        'character': '©',
                        'wrap_tag': config.get('wrap_tag', 'sup'),
                        'enabled': True
                    })

            # Handle legacy registered_symbol
            if 'registered_symbol' in self.special_chars:
                config = self.special_chars['registered_symbol']
                if config.get('enabled', True):
                    char_configs.append({
                        'character': '®',
                        'wrap_tag': config.get('wrap_tag', 'sup'),
                        'enabled': True
                    })
        elif isinstance(self.special_chars, list):
            # New format: [{character, wrap_tag, enabled}, ...]
            char_configs = self.special_chars
        else:
            char_configs = []

        # Apply transformations for each configured character
        for config in char_configs:
            if not config.get('enabled', True):
                continue

            character = config.get('character', '')
            wrap_tag = config.get('wrap_tag', 'sup')

            if not character:
                continue

            # Escape the character for use in regex
            escaped_char = re.escape(character)

            # Replace the character with wrapped version
            html = re.sub(escaped_char, f'<{wrap_tag}>{character}</{wrap_tag}>', html)

        return html

    def _apply_replacements(self, html: str) -> str:
        """
        Apply custom search and replace rules.

        Args:
            html: HTML string

        Returns:
            Transformed HTML string
        """
        for replacement in self.replacements:
            search = replacement.get('search', '')
            replace = replacement.get('replace', '')
            case_sensitive = replacement.get('case_sensitive', True)

            if not search:
                continue

            if case_sensitive:
                html = html.replace(search, replace)
            else:
                # Case-insensitive replacement
                pattern = re.compile(re.escape(search), re.IGNORECASE)
                html = pattern.sub(replace, html)

        return html

    @staticmethod
    def _escape_html(text: str) -> str:
        """
        Escape HTML special characters.

        Args:
            text: Text to escape

        Returns:
            Escaped text
        """
        replacements = {
            '&': '&amp;',
            '<': '&lt;',
            '>': '&gt;',
            '"': '&quot;',
            "'": '&#39;'
        }

        for char, escape in replacements.items():
            text = text.replace(char, escape)

        return text

    def _count_quotes(self, text: str) -> int:
        """
        Count all types of quotation marks in text.

        Args:
            text: Text to count quotes in

        Returns:
            Total count of all quote types
        """
        quote_types = self.quote_detection.get('quote_types', ['"', '"', '"', "'", "'"])
        count = sum(text.count(qt) for qt in quote_types)
        return count

    def _parse_wrap_tag(self, wrap_tag: str) -> tuple:
        """
        Parse wrap_tag to extract tag name and attributes.

        Supports both:
        - Simple tag: "blockquote"
        - Tag with attributes: "div class=\"quote\""

        Args:
            wrap_tag: Tag specification (simple name or tag with attributes)

        Returns:
            Tuple of (opening_tag, closing_tag)
            e.g., ('<div class="quote">', '</div>')
        """
        wrap_tag = wrap_tag.strip()

        # Check if it contains a space (indicates attributes)
        if ' ' in wrap_tag:
            # Extract tag name (first word)
            parts = wrap_tag.split(None, 1)
            tag_name = parts[0]
            # Full opening tag with attributes
            opening_tag = f'<{wrap_tag}>'
            closing_tag = f'</{tag_name}>'
        else:
            # Simple tag name
            opening_tag = f'<{wrap_tag}>'
            closing_tag = f'</{wrap_tag}>'

        return (opening_tag, closing_tag)


def get_app_config_dir() -> Path:
    """
    Get the application configuration directory, creating it if needed.

    Returns:
        Path to the application config directory
    """
    # Standard macOS application support directory
    app_support = Path.home() / 'Library' / 'Application Support' / 'makeHTML'
    app_support.mkdir(parents=True, exist_ok=True)
    return app_support


def get_default_config() -> Dict[str, Any]:
    """
    Get the default configuration.

    NOTE: This is a minimal fallback. The actual default config is stored in
    config.json and deployed by the Swift app. This function should rarely be used.

    Returns:
        Minimal default configuration dictionary
    """
    return {
        'output': {
            'paragraph_tag': 'p',
            'heading_tag': 'h3'
        },
        'special_characters': [],
        'replacements': [],
        'quote_detection': {
            'enabled': False,
            'threshold': 3,
            'wrap_tag': 'div class="blockquote"',
            'quote_types': []
        },
        'code_snippets': []
    }


def load_config(config_path: Optional[str] = None) -> Dict[str, Any]:
    """
    Load configuration from JSON file using hybrid approach:
    1. If config_path is explicitly provided, use that
    2. Otherwise, check ~/Library/Application Support/makeHTML/config.json
    3. If that doesn't exist, check script directory for config.json
    4. If neither exists, create config in Application Support with defaults

    Args:
        config_path: Path to config file, or None for auto-detection

    Returns:
        Configuration dictionary
    """
    if config_path is not None:
        # Explicit config path provided via command line
        config_path = Path(config_path)
        if not config_path.exists():
            print(f"Warning: Config file not found: {config_path}", file=sys.stderr)
            print("Using default configuration.", file=sys.stderr)
            return get_default_config()

        with open(config_path, 'r', encoding='utf-8') as f:
            return json.load(f)

    # Auto-detect config location (hybrid approach)

    # Priority 1: User's Application Support directory
    user_config_path = get_app_config_dir() / 'config.json'

    # Priority 2: Script directory (for development/backwards compatibility)
    script_config_path = Path(__file__).parent / 'config.json'

    if user_config_path.exists():
        # Use existing user config
        try:
            with open(user_config_path, 'r', encoding='utf-8') as f:
                return json.load(f)
        except Exception as e:
            print(f"Error loading config from {user_config_path}: {e}", file=sys.stderr)
            print("Using default configuration.", file=sys.stderr)
            return get_default_config()

    elif script_config_path.exists():
        # Use script directory config (backwards compatibility)
        try:
            with open(script_config_path, 'r', encoding='utf-8') as f:
                return json.load(f)
        except Exception as e:
            print(f"Error loading config from {script_config_path}: {e}", file=sys.stderr)
            print("Using default configuration.", file=sys.stderr)
            return get_default_config()

    else:
        # No config found - create default config in user's Application Support
        print(f"Creating default configuration at: {user_config_path}", file=sys.stderr)
        default_config = get_default_config()

        try:
            with open(user_config_path, 'w', encoding='utf-8') as f:
                json.dump(default_config, f, indent=2)
            print(f"Configuration file created. You can edit it at: {user_config_path}", file=sys.stderr)
        except Exception as e:
            print(f"Warning: Could not create config file: {e}", file=sys.stderr)

        return default_config


def main():
    """Main entry point for the script."""
    parser = argparse.ArgumentParser(
        description='Convert DOCX files to clean HTML with configurable formatting.'
    )
    parser.add_argument(
        'input',
        help='Path to input DOCX file'
    )
    parser.add_argument(
        '-o', '--output',
        help='Path to output HTML file (default: same name as input with .html extension)'
    )
    parser.add_argument(
        '-c', '--config',
        help='Path to configuration JSON file (default: config.json in script directory)'
    )

    args = parser.parse_args()

    # Validate input file
    input_path = Path(args.input)
    if not input_path.exists():
        print(f"Error: Input file not found: {args.input}", file=sys.stderr)
        sys.exit(1)

    if not input_path.suffix.lower() == '.docx':
        print(f"Error: Input file must be a .docx file", file=sys.stderr)
        sys.exit(1)

    # Determine output path
    if args.output:
        output_path = Path(args.output)
    else:
        output_path = input_path.with_suffix('.html')

    # Load configuration
    config = load_config(args.config)

    # Convert
    try:
        print(f"Converting {input_path} to HTML...")
        converter = DocxToHtmlConverter(config)
        html = converter.convert_docx_to_html(str(input_path))

        # Write output
        with open(output_path, 'w', encoding='utf-8') as f:
            f.write(html)

        print(f"Successfully converted to {output_path}")

    except Exception as e:
        print(f"Error during conversion: {e}", file=sys.stderr)
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == '__main__':
    main()
