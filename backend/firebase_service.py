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
