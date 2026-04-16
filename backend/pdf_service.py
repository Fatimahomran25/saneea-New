
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
    custom_clauses = contract_data.get("customClauses", [])

    status_raw = str(approval.get("contractStatus", "draft")).strip().lower()
    status = status_raw.replace("_", " ").title()

    client_approval = "Approved" if approval.get("clientApproved") else "Pending"
    freelancer_approval = "Approved" if approval.get("freelancerApproved") else "Pending"

    base_dir = os.path.dirname(__file__)
    logo_path = os.path.join(base_dir, "assets", "LOGO.png")

    print("LOGO PATH:", logo_path)
    print("LOGO EXISTS:", os.path.exists(logo_path))

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

    draw_header()
    draw_status_box()

    draw_section("Contract Parties")
    draw_label_value("Client", parties.get("clientName", "-"))
    draw_label_value("Freelancer", parties.get("freelancerName", "-"))

    y -= 4
    draw_section("Service Description")
    draw_paragraph(service.get("description", "-"))

    y -= 2
    draw_section("Payment")
    amount = payment.get("amount", "-")
    currency = payment.get("currency", "")
    payment_text = f"{amount} {currency}".strip()
    draw_paragraph(payment_text if payment_text else "-")

    y -= 2
    draw_section("Deadline")
    draw_paragraph(timeline.get("deadline", "-"))

    y -= 2
    draw_section("Approval Status")
    draw_label_value("Client Approval", client_approval)
    draw_label_value("Freelancer Approval", freelancer_approval)

    if custom_clauses:
        y -= 2
        draw_section("Additional Clauses")
        for i, clause in enumerate(custom_clauses, start=1):
            ensure_space(4)

            title = clause.get("title", f"Clause {i}")
            content = clause.get("content", "-")

            pdf.setFillColor(colors.HexColor("#FBFAFE"))
            pdf.setStrokeColor(colors.HexColor("#E7E0F5"))
            card_height = 60
            card_y = y - card_height + 18
            pdf.roundRect(55, card_y, width - 110, card_height, 12, fill=1, stroke=1)

            pdf.setFont("Helvetica-Bold", 12)
            pdf.setFillColor(colors.HexColor("#2A223A"))
            pdf.drawString(68, y, f"{i}. {title}")

            y -= 22
            pdf.setFont("Helvetica", 11)
            pdf.setFillColor(colors.black)
            pdf.drawString(68, y, str(content)[:85])

            y = card_y - 18

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