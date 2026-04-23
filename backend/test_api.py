import requests

url = "http://192.168.8.5:5001/approve-contract"

data = {
    "requestId": "Hs4QeooY6zUt1Lc32gNDjrhuTcA3_SjALgOs30cYueSp8penIpeJfqQv2",
    "role": "client"
}

response = requests.post(url, json=data)

print(response.json())
