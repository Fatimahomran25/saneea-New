import base64
import os
from io import BytesIO

from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.utils import ImageReader
from reportlab.pdfgen import canvas


def generate_contract_pdf(contract_data):
    buffer = BytesIO()
    pdf = canvas.Canvas(buffer, pagesize=A4)

    width, height = A4
    y = height - 55

    def as_dict(value):
        return value if isinstance(value, dict) else {}

    def as_list(value):
        return value if isinstance(value, list) else []

    contract_data = as_dict(contract_data)

    parties = as_dict(contract_data.get("parties"))
    service = as_dict(contract_data.get("service"))
    payment = as_dict(contract_data.get("payment"))
    timeline = as_dict(contract_data.get("timeline"))
    meta = as_dict(contract_data.get("meta"))
    approval = as_dict(contract_data.get("approval"))
    signatures = as_dict(contract_data.get("signatures"))
    custom_clauses = as_list(contract_data.get("customClauses"))

    client_name = parties.get("clientName", "-")
    freelancer_name = parties.get("freelancerName", "-")
    service_ai_text = service.get("aiText")
    service_raw_description = service.get("description", "-")
    payment_amount = payment.get("amount", "-")
    payment_currency = payment.get("currency", "")
    deadline = timeline.get("deadline", "-")
    contract_created_at = meta.get("createdAt", "-")
    contract_title = meta.get("title", "CONTRACT AGREEMENT")
    contract_status = approval.get("contractStatus", "draft")
    client_signature = signatures.get("clientSignature")
    freelancer_signature = signatures.get("freelancerSignature")

    status_raw = str(contract_status).strip().lower()
    status = status_raw.replace("_", " ").title()

    base_dir = os.path.dirname(__file__)
    project_root = os.path.abspath(os.path.join(base_dir, os.pardir))
    logo_path = os.path.abspath(
        os.path.join(project_root, "assets", "LOGO.png")
    )

    def normalize_text(value):
        return " ".join(str(value or "").strip().lower().split())

    def safe_text(value, fallback="-"):
        if value is None:
            return fallback
        text = str(value).strip()
        return text if text else fallback

    service_description = safe_text(service_ai_text, "")
    if service_description == "":
        service_description = safe_text(service_raw_description)

    def get_status_color():
        if status_raw == "approved":
            return colors.HexColor("#2E7D32")
        if status_raw == "rejected":
            return colors.HexColor("#C62828")
        if status_raw == "pending_approval":
            return colors.HexColor("#EF6C00")
        if status_raw == "edited":
            return colors.HexColor("#7E57C2")
        return colors.HexColor("#5A3E9E")

    section_left = 55
    section_width = width - 110
    card_radius = 12
    section_gap = 12
    card_inner_padding_x = 14
    card_inner_padding_y = 12
    body_font = "Helvetica"
    body_font_size = 11
    body_line_height = 16
    section_fill = colors.HexColor("#FCFBFE")
    section_stroke = colors.HexColor("#E7E0F5")
    section_title_fill = colors.HexColor("#F1ECFA")
    section_title_text = colors.HexColor("#5A3E9E")
    body_text_color = colors.HexColor("#2A223A")
    label_text_color = colors.HexColor("#5E556F")

    def wrap_text_lines(text, max_width, font_name=body_font, font_size=body_font_size):
        raw_text = str(text).strip() if text not in [None, ""] else "-"
        paragraphs = raw_text.splitlines() or ["-"]
        wrapped_lines = []

        for index, paragraph in enumerate(paragraphs):
            cleaned = paragraph.strip()
            if not cleaned:
                wrapped_lines.append("")
                continue

            words = cleaned.split()
            line = ""

            for word in words:
                candidate = word if not line else f"{line} {word}"
                if pdf.stringWidth(candidate, font_name, font_size) <= max_width:
                    line = candidate
                else:
                    if line:
                        wrapped_lines.append(line)
                    line = word

            if line:
                wrapped_lines.append(line)

            if index < len(paragraphs) - 1 and cleaned:
                wrapped_lines.append("")

        return wrapped_lines or ["-"]

    def draw_content_card(x, top_y, card_width, card_height, fill_color=section_fill):
        bottom_y = top_y - card_height
        pdf.setFillColor(fill_color)
        pdf.setStrokeColor(section_stroke)
        pdf.setLineWidth(1)
        pdf.roundRect(
            x,
            bottom_y,
            card_width,
            card_height,
            card_radius,
            fill=1,
            stroke=1,
        )
        return bottom_y

    def new_page():
        nonlocal y
        pdf.showPage()
        y = height - 55
        draw_header()

    def ensure_height(required_height):
        nonlocal y
        if y - required_height < 80:
            new_page()

    def draw_header():
        nonlocal y
        header_x = 40
        header_y = height - 122
        header_width = width - 80
        header_height = 78
        logo_panel_x = header_x + 14
        logo_panel_y = header_y + 12
        logo_panel_size = 54
        separator_x = header_x + 90
        meta_width = 112
        meta_height = 42
        meta_x = header_x + header_width - meta_width - 14
        meta_y = header_y + ((header_height - meta_height) / 2)
        title_x = separator_x + 18

        pdf.setFillColor(colors.HexColor("#F8F6FC"))
        pdf.setStrokeColor(colors.HexColor("#E7E0F5"))
        pdf.setLineWidth(1)
        pdf.roundRect(
            header_x,
            header_y,
            header_width,
            header_height,
            16,
            fill=1,
            stroke=1,
        )

        pdf.setFillColor(colors.HexColor("#EEE8FA"))
        pdf.roundRect(
            logo_panel_x,
            logo_panel_y,
            logo_panel_size,
            logo_panel_size,
            12,
            fill=1,
            stroke=0,
        )

        if os.path.exists(logo_path):
            try:
                logo = ImageReader(logo_path)
                pdf.drawImage(
                    logo,
                    logo_panel_x + 8,
                    logo_panel_y + 8,
                    width=logo_panel_size - 16,
                    height=logo_panel_size - 16,
                    preserveAspectRatio=True,
                    mask="auto",
                )
            except Exception as error:
                print("ERROR DRAWING LOGO:", error)

        pdf.setStrokeColor(colors.HexColor("#DDD4EE"))
        pdf.setLineWidth(1)
        pdf.line(separator_x, header_y + 12, separator_x, header_y + header_height - 12)

        pdf.setFillColor(colors.white)
        pdf.setStrokeColor(colors.HexColor("#E7E0F5"))
        pdf.roundRect(meta_x, meta_y, meta_width, meta_height, 12, fill=1, stroke=1)

        pdf.setFont("Helvetica", 8)
        pdf.setFillColor(colors.HexColor("#7A748C"))
        pdf.drawString(meta_x + 12, meta_y + meta_height - 14, "Contract Date")

        pdf.setFont("Helvetica-Bold", 10)
        pdf.setFillColor(colors.HexColor("#2A223A"))
        pdf.drawString(meta_x + 12, meta_y + 12, safe_text(contract_created_at))

        pdf.setFillColor(colors.HexColor("#2A223A"))
        pdf.setFont("Helvetica-Bold", 18)

        title_text = safe_text(contract_title, "CONTRACT AGREEMENT").upper()
        title_max_width = meta_x - title_x - 16
        title_lines = wrap_text_lines(title_text, title_max_width, "Helvetica-Bold", 18)

        current_y = header_y + 47
        for line in title_lines[:2]:
            if line:
                pdf.drawString(title_x, current_y, line)
            current_y -= 18

        pdf.setFont("Helvetica", 10)
        pdf.setFillColor(colors.HexColor("#6B6480"))
        pdf.drawString(title_x, header_y + 16, "Official contract summary")

        y = header_y - 18

    def draw_section(title):
        nonlocal y
        ensure_height(44)

        badge_padding_x = 12
        badge_height = 22
        badge_width = pdf.stringWidth(title, "Helvetica-Bold", 12) + (badge_padding_x * 2)
        badge_bottom_y = y - 14

        pdf.setFillColor(section_title_fill)
        pdf.roundRect(
            section_left,
            badge_bottom_y,
            badge_width,
            badge_height,
            11,
            fill=1,
            stroke=0,
        )

        pdf.setFont("Helvetica-Bold", 12)
        pdf.setFillColor(section_title_text)
        pdf.drawString(section_left + badge_padding_x, badge_bottom_y + 6.5, title)

        y = badge_bottom_y - 12

    def draw_status_box():
        nonlocal y
        box_height = 72
        ensure_height(box_height + section_gap)

        top_y = y
        bottom_y = draw_content_card(
            section_left,
            top_y,
            section_width,
            box_height,
            fill_color=colors.HexColor("#FBFAFE"),
        )

        label_x = section_left + card_inner_padding_x
        label_top_y = top_y - 16
        value_top_y = label_top_y - 16
        chip_height = 24
        chip_padding_x = 12
        status_font = "Helvetica-Bold"
        status_font_size = 10
        status_chip_width = pdf.stringWidth(status, status_font, status_font_size) + (chip_padding_x * 2)
        chip_x = section_left + section_width - card_inner_padding_x - status_chip_width
        chip_y = top_y - 48

        pdf.setFont("Helvetica-Bold", 10)
        pdf.setFillColor(label_text_color)
        pdf.drawString(label_x, label_top_y, "Contract Date")
        pdf.drawString(label_x, chip_y + 7, "Contract Status")

        pdf.setFont("Helvetica-Bold", 12)
        pdf.setFillColor(body_text_color)
        pdf.drawString(label_x, value_top_y, safe_text(contract_created_at))

        pdf.setFillColor(get_status_color())
        pdf.roundRect(
            chip_x,
            chip_y,
            status_chip_width,
            chip_height,
            12,
            fill=1,
            stroke=0,
        )

        pdf.setFont(status_font, status_font_size)
        pdf.setFillColor(colors.white)
        pdf.drawString(chip_x + chip_padding_x, chip_y + 7, status)

        pdf.setStrokeColor(section_stroke)
        pdf.setLineWidth(1)
        pdf.line(
            section_left + card_inner_padding_x,
            bottom_y + 34,
            section_left + section_width - card_inner_padding_x,
            bottom_y + 34,
        )

        pdf.setFont(body_font, 9)
        pdf.setFillColor(label_text_color)
        pdf.drawString(
            section_left + card_inner_padding_x,
            bottom_y + 14,
            "This is the current contract approval state.",
        )

        y = bottom_y - section_gap

    def draw_parties_section():
        nonlocal y

        draw_section("Contract Parties")

        card_gap = 12
        party_card_width = (section_width - card_gap) / 2
        party_card_height = 58

        ensure_height(party_card_height + section_gap)
        top_y = y

        def draw_party_card(x, label, value):
            safe_value = safe_text(value)
            bottom_y = draw_content_card(
                x,
                top_y,
                party_card_width,
                party_card_height,
                fill_color=colors.HexColor("#FBFAFE"),
            )
            text_x = x + card_inner_padding_x
            label_y = top_y - 16
            value_y = top_y - 36

            pdf.setFont("Helvetica-Bold", 10)
            pdf.setFillColor(label_text_color)
            pdf.drawString(text_x, label_y, label)

            pdf.setFont("Helvetica-Bold", 12)
            pdf.setFillColor(body_text_color)
            value_lines = wrap_text_lines(
                safe_value,
                party_card_width - (card_inner_padding_x * 2),
                font_name="Helvetica-Bold",
                font_size=12,
            )

            current_y = value_y
            for line in value_lines[:2]:
                if line:
                    pdf.drawString(text_x, current_y, line)
                current_y -= 15

            return bottom_y

        left_x = section_left
        right_x = section_left + party_card_width + card_gap

        draw_party_card(left_x, "Client", client_name)
        bottom_y = draw_party_card(right_x, "Freelancer", freelancer_name)

        y = bottom_y - section_gap

    def draw_service_description_section():
        nonlocal y

        draw_section("Service Description")

        content_lines = wrap_text_lines(
            safe_text(service_description),
            section_width - (card_inner_padding_x * 2),
            font_name=body_font,
            font_size=body_font_size,
        )
        text_block_height = max(body_line_height, len(content_lines) * body_line_height)
        card_height = max(72, (card_inner_padding_y * 2) + text_block_height + 6)

        ensure_height(card_height + section_gap)
        top_y = y
        bottom_y = draw_content_card(
            section_left,
            top_y,
            section_width,
            card_height,
            fill_color=colors.HexColor("#FBFAFE"),
        )

        text_x = section_left + card_inner_padding_x
        current_y = top_y - card_inner_padding_y - 2

        pdf.setFont(body_font, body_font_size)
        pdf.setFillColor(body_text_color)

        for line in content_lines:
            if line:
                pdf.drawString(text_x, current_y, line)
            current_y -= body_line_height

        y = bottom_y - section_gap

    def draw_payment_deadline_section():
        nonlocal y

        draw_section("Payment & Deadline")

        card_gap = 12
        info_card_width = (section_width - card_gap) / 2

        amount = safe_text(payment_amount)
        currency = safe_text(payment_currency, "")
        payment_text = f"{amount} {currency}".strip() if currency else amount
        deadline_text = safe_text(deadline)

        amount_lines = wrap_text_lines(
            payment_text,
            info_card_width - (card_inner_padding_x * 2),
            font_name="Helvetica-Bold",
            font_size=13,
        )
        deadline_lines = wrap_text_lines(
            deadline_text,
            info_card_width - (card_inner_padding_x * 2),
            font_name=body_font,
            font_size=body_font_size,
        )

        content_height = max(
            len(amount_lines) * 17,
            len(deadline_lines) * body_line_height,
        )
        card_height = max(72, (card_inner_padding_y * 2) + content_height + 8)

        ensure_height(card_height + section_gap)
        top_y = y

        def draw_info_card(x, label, lines, value_font, value_size, value_color):
            bottom_y = draw_content_card(
                x,
                top_y,
                info_card_width,
                card_height,
                fill_color=colors.HexColor("#FBFAFE"),
            )
            text_x = x + card_inner_padding_x
            label_y = top_y - 16
            value_y = top_y - 38

            pdf.setFont("Helvetica-Bold", 10)
            pdf.setFillColor(label_text_color)
            pdf.drawString(text_x, label_y, label)

            pdf.setFont(value_font, value_size)
            pdf.setFillColor(value_color)
            current_y = value_y

            for line in lines:
                if line:
                    pdf.drawString(text_x, current_y, line)
                current_y -= 17 if value_size >= 13 else body_line_height

            return bottom_y

        left_x = section_left
        right_x = section_left + info_card_width + card_gap

        draw_info_card(
            left_x,
            "Amount",
            amount_lines,
            "Helvetica-Bold",
            13,
            body_text_color,
        )
        bottom_y = draw_info_card(
            right_x,
            "Deadline",
            deadline_lines,
            body_font,
            body_font_size,
            body_text_color,
        )

        y = bottom_y - section_gap

    def draw_clause_group_section(title, contents):
        nonlocal y

        clean_contents = [str(content).strip() for content in contents if str(content).strip()]
        if not clean_contents:
            return

        draw_section(title)

        content_width = section_width - (card_inner_padding_x * 2)
        clause_card_gap = 8

        for index, content in enumerate(clean_contents):
            content_lines = wrap_text_lines(
                content,
                content_width,
                font_name=body_font,
                font_size=body_font_size,
            )
            text_block_height = max(body_line_height, len(content_lines) * body_line_height)
            card_height = max(64, (card_inner_padding_y * 2) + text_block_height + 4)

            ensure_height(card_height + section_gap)
            top_y = y
            bottom_y = draw_content_card(
                section_left,
                top_y,
                section_width,
                card_height,
                fill_color=colors.HexColor("#FBFAFE"),
            )

            text_x = section_left + card_inner_padding_x
            current_y = top_y - card_inner_padding_y - 2

            pdf.setFont(body_font, body_font_size)
            pdf.setFillColor(body_text_color)

            for line in content_lines:
                if line:
                    pdf.drawString(text_x, current_y, line)
                current_y -= body_line_height

            y = bottom_y - (section_gap if index == len(clean_contents) - 1 else clause_card_gap)

    def decode_signature_image(signature_data):
        if not isinstance(signature_data, str):
            return None

        cleaned_signature = signature_data.strip()
        if not cleaned_signature:
            return None

        if cleaned_signature.startswith("data:") and "," in cleaned_signature:
            cleaned_signature = cleaned_signature.split(",", 1)[1]

        try:
            signature_bytes = base64.b64decode(cleaned_signature)
            return ImageReader(BytesIO(signature_bytes))
        except Exception as error:
            print("ERROR DECODING SIGNATURE:", error)
            return None

    def draw_signature_card(label, signature_data, x, top_y, card_width, card_height):
        bottom_y = draw_content_card(
            x,
            top_y,
            card_width,
            card_height,
            fill_color=colors.HexColor("#FBFAFE"),
        )

        header_x = x + 12
        header_width = card_width - 24
        header_height = 22
        header_y = top_y - 30

        pdf.setFillColor(colors.HexColor("#F2EDFA"))
        pdf.roundRect(
            header_x,
            header_y,
            header_width,
            header_height,
            11,
            fill=1,
            stroke=0,
        )

        pdf.setFont("Helvetica-Bold", 10)
        pdf.setFillColor(section_title_text)
        label_width = pdf.stringWidth(label, "Helvetica-Bold", 10)
        pdf.drawString(
            x + ((card_width - label_width) / 2),
            header_y + 7,
            label,
        )

        signature_image = decode_signature_image(signature_data)

        image_area_width = card_width - 28
        image_area_height = card_height - 62
        image_x = x + 14
        image_y = bottom_y + 14

        if signature_image is None:
            pdf.setFont("Helvetica-Oblique", 10)
            pdf.setFillColor(colors.grey)
            placeholder = "Signature unavailable"
            placeholder_width = pdf.stringWidth(placeholder, "Helvetica-Oblique", 10)
            pdf.drawString(
                x + ((card_width - placeholder_width) / 2),
                image_y + (image_area_height / 2),
                placeholder,
            )
            return

        try:
            image_width, image_height = signature_image.getSize()

            if image_width <= 0 or image_height <= 0:
                raise ValueError("Invalid signature image size")

            scale = min(image_area_width / image_width, image_area_height / image_height)
            draw_width = image_width * scale
            draw_height = image_height * scale
            draw_x = image_x + ((image_area_width - draw_width) / 2)
            draw_y = image_y + ((image_area_height - draw_height) / 2)

            pdf.drawImage(
                signature_image,
                draw_x,
                draw_y,
                width=draw_width,
                height=draw_height,
                preserveAspectRatio=True,
                mask="auto",
            )
        except Exception as error:
            print("ERROR DRAWING SIGNATURE:", error)
            pdf.setFont("Helvetica-Oblique", 10)
            pdf.setFillColor(colors.grey)
            placeholder = "Signature unavailable"
            placeholder_width = pdf.stringWidth(placeholder, "Helvetica-Oblique", 10)
            pdf.drawString(
                x + ((card_width - placeholder_width) / 2),
                image_y + (image_area_height / 2),
                placeholder,
            )

    def draw_signatures_section():
        nonlocal y

        ensure_height(188)
        y -= 2
        draw_section("Signatures")

        card_width = (width - 126) / 2
        gap = 16
        card_height = 112
        top_y = y

        draw_signature_card(
            "Client Signature",
            client_signature,
            55,
            top_y,
            card_width,
            card_height,
        )
        draw_signature_card(
            "Freelancer Signature",
            freelancer_signature,
            55 + card_width + gap,
            top_y,
            card_width,
            card_height,
        )

        y = top_y - card_height - 18

    def draw_footer():
        nonlocal y

        primary_text = "This document represents the latest contract version stored in the system."
        secondary_text = "Generated by Saneea Contract System"

        if y < 78:
            new_page()

        divider_y = min(y - 6, 92)
        divider_width = section_width - 70
        divider_x = (width - divider_width) / 2

        pdf.setStrokeColor(colors.HexColor("#E7E0F5"))
        pdf.setLineWidth(1)
        pdf.line(divider_x, divider_y, divider_x + divider_width, divider_y)

        primary_y = divider_y - 18
        secondary_y = primary_y - 14

        pdf.setFont("Helvetica", 9)
        pdf.setFillColor(colors.HexColor("#4B4659"))
        primary_width = pdf.stringWidth(primary_text, "Helvetica", 9)
        pdf.drawString((width - primary_width) / 2, primary_y, primary_text)

        pdf.setFont("Helvetica-Oblique", 8)
        pdf.setFillColor(colors.HexColor("#7A748C"))
        secondary_width = pdf.stringWidth(
            secondary_text,
            "Helvetica-Oblique",
            8,
        )
        pdf.drawString((width - secondary_width) / 2, secondary_y, secondary_text)

        y = secondary_y - 10

    draw_header()
    draw_status_box()
    draw_parties_section()

    y -= 4
    draw_service_description_section()

    y -= 2
    draw_payment_deadline_section()

    # عرض جميع البنود الموجودة في customClauses بدون تقييد بعنوان أو source
    grouped_clauses = {}

    for clause in custom_clauses:
        if not isinstance(clause, dict):
            continue

        title = safe_text(clause.get("title"), "Other")
        raw_clause_content = clause.get("content")
        if raw_clause_content in (None, ""):
            raw_clause_content = clause.get("text")
        content = safe_text(raw_clause_content, "")

        if not content.strip():
            continue

        normalized_title = normalize_text(title)
        if normalized_title not in grouped_clauses:
            grouped_clauses[normalized_title] = {
                "display_title": title,
                "contents": []
            }

        if content not in grouped_clauses[normalized_title]["contents"]:
            grouped_clauses[normalized_title]["contents"].append(content)

    for _, item in grouped_clauses.items():
        y -= 2
        draw_clause_group_section(item["display_title"], item["contents"])

    if status_raw == "approved":
        draw_signatures_section()

    draw_footer()

    pdf.save()
    buffer.seek(0)
    return buffer
