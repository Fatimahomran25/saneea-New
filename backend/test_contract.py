from contract_controller import generate_contract_from_request_id

request_id = "Hs4QeooY6zUt1Lc32gNDjrhuTcA3_SjALgOs30cYueSp8penIpeJfqQv2"

result = generate_contract_from_request_id(request_id)

if not result["success"]:
    print(result["error"])
else:
    contract_text = result["contractText"]

    with open("generated_contract.txt", "w", encoding="utf-8") as file:
        file.write(contract_text)

    print("Contract generated and saved ✅")