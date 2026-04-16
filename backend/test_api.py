import requests

url = "http://10.0.2.2:5001/approve-contract"

data = {
    "requestId": "Hs4QeooY6zUt1Lc32gNDjrhuTcA3_SjALgOs30cYueSp8penIpeJfqQv2",
    "role": "client"
}

response = requests.post(url, json=data)

print(response.json())