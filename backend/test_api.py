import requests

url = "http://127.0.0.1:5000/approve-contract"

data = {
    "requestId": "Hs4QeooY6zUt1Lc32gNDjrhuTcA3_SjALgOs30cYueSp8penIpeJfqQv2",
    "role": "client"
}

response = requests.post(url, json=data)

print(response.json())