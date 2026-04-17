import firebase_admin
from firebase_admin import credentials, firestore

# Initialize Firebase only once.
if not firebase_admin._apps:
    cred = credentials.Certificate("serviceAccountKey.json")
    firebase_admin.initialize_app(cred)

db = firestore.client()


def get_request_by_id(request_id):
    doc = db.collection("requests").document(request_id).get()

    if not doc.exists:
        return None

    return doc.to_dict()


def update_request_contract_data(request_id, contract_data):
    # Save the updated contract inside the existing request document.
    db.collection("requests").document(request_id).update({
        "contractData": contract_data
    })


def delete_request_contract_data(request_id):
    db.collection("requests").document(request_id).update({
        "contractData": firestore.DELETE_FIELD
    })


def create_approved_contract_chat_message(
    request_id,
    request_data,
    contract_data,
    sender_role,
    contract_text="",
):
    chat_ref = db.collection("chat").document(request_id)
    chat_doc = chat_ref.get()
    chat_data = chat_doc.to_dict() if chat_doc.exists else {}

    client_id = str(request_data.get("clientId", "")).strip()
    freelancer_id = str(request_data.get("freelancerId", "")).strip()

    sender_id = client_id if sender_role == "client" else freelancer_id

    meta = contract_data.get("meta", {})
    approval = contract_data.get("approval", {})
    summary = meta.get("summary", [])

    if not isinstance(summary, list):
        summary = []

    unread_count_client = int(chat_data.get("unreadCountClient", 0) or 0)
    unread_count_freelancer = int(chat_data.get("unreadCountFreelancer", 0) or 0)

    if sender_role == "client":
        unread_count_freelancer += 1
    else:
        unread_count_client += 1

    chat_ref.collection("messages").add({
        "senderId": sender_id,
        "text": "Approved Contract",
        "type": "contract",
        "requestId": request_id,
        "status": approval.get("contractStatus", ""),
        "contractStatus": approval.get("contractStatus", ""),
        "contractTitle": meta.get("title", ""),
        "contractSummary": summary,
        "contractText": contract_text,
        "timestamp": firestore.SERVER_TIMESTAMP,
        "isRead": False,
    })

    chat_ref.set({
        "clientId": client_id,
        "freelancerId": freelancer_id,
        "requestId": request_id,
        "lastMessage": "Approved Contract",
        "updatedAt": firestore.SERVER_TIMESTAMP,
        "unreadCountClient": unread_count_client,
        "unreadCountFreelancer": unread_count_freelancer,
    }, merge=True)
