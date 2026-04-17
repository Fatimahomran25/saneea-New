
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

    parties = contract_data.get("parties", {})
    service = contract_data.get("service", {})
    payment = contract_data.get("payment", {})
    timeline = contract_data.get("timeline", {})
    meta = contract_data.get("meta", {})
    approval = contract_data.get("approval", {})
    signatures = contract_data.get("signatures", {})
    custom_clauses = contract_data.get("customClauses", [])

    status_raw = str(approval.get("contractStatus", "draft")).strip().lower()
    status = status_raw.replace("_", " ").title()

    base_dir = os.path.dirname(__file__)
    logo_path = os.path.join(base_dir, "assets", "LOGO.png")

    print("LOGO PATH:", logo_path)
    print("LOGO EXISTS:", os.path.exists(logo_path))

    def normalize_text(value):
        return " ".join(str(value or "").strip().lower().split())

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

    def new_page():
        nonlocal y
        pdf.showPage()
        y = height - 55
        draw_header()

    def ensure_space(lines=3):
        nonlocal y
        if y < 90 + (lines * 22):
            new_page()

    def ensure_height(required_height):
        nonlocal y
        if y - required_height < 70:
            new_page()

    def draw_header():
        nonlocal y
        y = height - 55

        pdf.setFillColor(colors.HexColor("#F7F4FC"))
        pdf.roundRect(45, height - 98, width - 90, 58, 12, fill=1, stroke=0)

        # خلفية خلف اللوقو عشان يبان
        pdf.setFillColor(colors.HexColor("#EEE8FA"))
        pdf.roundRect(55, height - 90, 42, 42, 8, fill=1, stroke=0)

        if os.path.exists(logo_path):
            try:
                logo = ImageReader(logo_path)
                pdf.drawImage(
                    logo,
                    59,
                    height - 86,
                    width=34,
                    height=34,
                    preserveAspectRatio=True,
                    mask="auto",
                )
            except Exception as e:
                print("ERROR DRAWING LOGO:", e)

        pdf.setFillColor(colors.HexColor("#2A223A"))
        pdf.setFont("Helvetica-Bold", 20)
        pdf.drawString(105, height - 63, "CONTRACT AGREEMENT")

        pdf.setFont("Helvetica", 10)
        pdf.setFillColor(colors.HexColor("#6B6480"))
        pdf.drawString(105, height - 79, "Official contract summary")

        y = height - 118

    def draw_section(title):
        nonlocal y
        ensure_space(2)

        pdf.setFont("Helvetica-Bold", 14)
        pdf.setFillColor(colors.HexColor("#5A3E9E"))
        pdf.drawString(55, y, title)

        pdf.setStrokeColor(colors.HexColor("#E7E0F5"))
        pdf.setLineWidth(1)
        pdf.line(55, y - 6, width - 55, y - 6)
        y -= 24

    def draw_label_value(label, value, value_x=170, value_color=colors.black):
        nonlocal y
        ensure_space(1)

        pdf.setFont("Helvetica-Bold", 12)
        pdf.setFillColor(colors.HexColor("#2A223A"))
        pdf.drawString(55, y, str(label))

        pdf.setFont("Helvetica", 12)
        pdf.setFillColor(value_color)
        safe_value = value if value not in [None, ""] else "-"
        pdf.drawString(value_x, y, str(safe_value))
        y -= 22

    def draw_paragraph(text):
        nonlocal y
        ensure_space(2)

        text = str(text).strip() if text not in [None, ""] else "-"
        words = text.split()
        line = ""

        pdf.setFont("Helvetica", 12)
        pdf.setFillColor(colors.black)

        for word in words:
            test_line = word if not line else f"{line} {word}"
            if len(test_line) <= 72:
                line = test_line
            else:
                pdf.drawString(55, y, line)
                y -= 20
                line = word
                ensure_space(1)

        if line:
            pdf.drawString(55, y, line)
            y -= 22

    def draw_status_box():
        nonlocal y
        ensure_space(3)

        box_height = 54
        box_y = y - box_height + 18

        pdf.setFillColor(colors.HexColor("#FBFAFE"))
        pdf.setStrokeColor(colors.HexColor("#E7E0F5"))
        pdf.roundRect(55, box_y, width - 110, box_height, 12, fill=1, stroke=1)

        pdf.setFont("Helvetica", 11)
        pdf.setFillColor(colors.HexColor("#2A223A"))
        pdf.drawString(70, y, f"Contract Date: {meta.get('createdAt', '-')}")
        pdf.drawString(70, y - 20, "Contract Status:")

        pdf.setFont("Helvetica-Bold", 11)
        pdf.setFillColor(get_status_color())
        pdf.drawString(170, y - 20, status)

        y = box_y - 20

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
        pdf.setFillColor(colors.HexColor("#FBFAFE"))
        pdf.setStrokeColor(colors.HexColor("#E7E0F5"))
        pdf.roundRect(x, top_y - card_height, card_width, card_height, 12, fill=1, stroke=1)

        pdf.setFont("Helvetica-Bold", 12)
        pdf.setFillColor(colors.HexColor("#2A223A"))
        pdf.drawString(x + 14, top_y - 18, label)

        signature_image = decode_signature_image(signature_data)

        image_area_width = card_width - 28
        image_area_height = card_height - 46
        image_x = x + 14
        image_y = top_y - card_height + 14

        if signature_image is None:
            pdf.setFont("Helvetica-Oblique", 10)
            pdf.setFillColor(colors.grey)
            pdf.drawString(image_x, image_y + (image_area_height / 2), "Signature unavailable")
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
            pdf.drawString(image_x, image_y + (image_area_height / 2), "Signature unavailable")

    def draw_signatures_section():
        nonlocal y

        ensure_height(170)
        y -= 2
        draw_section("Signatures")

        card_width = (width - 126) / 2
        gap = 16
        card_height = 96
        top_y = y

        client_signature = signatures.get("clientSignature") if isinstance(signatures, dict) else None
        freelancer_signature = signatures.get("freelancerSignature") if isinstance(signatures, dict) else None

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

    draw_header()
    draw_status_box()

    draw_section("Contract Parties")
    draw_label_value("Client", parties.get("clientName", "-"))
    draw_label_value("Freelancer", parties.get("freelancerName", "-"))

    y -= 4
    draw_section("Service Description")
    draw_paragraph(service.get("description", "-"))

    y -= 2
    draw_section("Amount")
    amount = payment.get("amount", "-")
    currency = payment.get("currency", "")
    payment_text = f"{amount} {currency}".strip()
    draw_paragraph(payment_text if payment_text else "-")

    y -= 2
    draw_section("Deadline")
    draw_paragraph(timeline.get("deadline", "-"))

    allowed_generated_section_titles = {
        "services": "Services",
        "payment terms": "Payment Terms",
        "revisions": "Revisions",
        "delivery": "Delivery",
        "confidentiality": "Confidentiality",
    }
    allowed_section_order = [
        "Services",
        "Payment Terms",
        "Revisions",
        "Delivery",
        "Confidentiality",
    ]
    generated_section_contents = {
        section_title: [] for section_title in allowed_section_order
    }

    for clause in custom_clauses:
        if not isinstance(clause, dict):
            continue

        title = normalize_text(clause.get("title"))
        content = str(clause.get("content") or clause.get("text") or "").strip()
        source = normalize_text(clause.get("source"))

        if not content or title == "deadline":
            continue

        is_ai_clause = source == "ai" or (
            not source and ("category" in clause or "optional" in clause)
        )

        if not is_ai_clause:
            continue

        section_title = allowed_generated_section_titles.get(title)
        if not section_title:
            continue

        if content not in generated_section_contents[section_title]:
            generated_section_contents[section_title].append(content)

    for section_title in allowed_section_order:
        section_contents = generated_section_contents[section_title]
        if section_contents:
            y -= 2
            draw_section(section_title)
            draw_paragraph("\n\n".join(section_contents))

    if status_raw == "approved":
        draw_signatures_section()

    ensure_space(3)
    pdf.setStrokeColor(colors.HexColor("#E7E0F5"))
    pdf.line(55, y, width - 55, y)
    y -= 16

    pdf.setFont("Helvetica", 9)
    pdf.setFillColor(colors.HexColor("#4B4659"))
    pdf.drawString(
        55,
        y,
        "This document represents the latest contract version stored in the system.",
    )
    y -= 12

    pdf.setFont("Helvetica-Oblique", 8)
    pdf.setFillColor(colors.grey)
    pdf.drawString(55, y, "Generated by Saneea Contract System")

    pdf.save()
    buffer.seek(0)
    return buffer
