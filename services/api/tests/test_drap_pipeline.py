from app.services.drap_parser import DrapParser


def test_drap_parser_composition():
    comp = "Amoxicillin 500mg + Clavulanic Acid 125mg"
    ingredients = DrapParser.parse_composition(comp)
    assert len(ingredients) == 2
    assert ingredients[0]["name"] == "Amoxicillin"
    assert ingredients[0]["value"] == "500"
    assert ingredients[0]["unit"] == "mg"
    assert ingredients[1]["name"] == "Clavulanic Acid"
    assert ingredients[1]["value"] == "125"
    assert ingredients[1]["unit"] == "mg"


def test_drap_parser_composition_complex():
    comp = "Paracetamol 120mg/5ml and Ibuprofen 100mg/5ml"
    ingredients = DrapParser.parse_composition(comp)
    assert len(ingredients) == 2
    assert ingredients[0]["name"] == "Paracetamol"
    assert ingredients[0]["value"] == "120"
    assert ingredients[0]["unit"] == "mg/5ml"


def test_drap_parser_csv():
    csv_data = (
        "Registration Number,Product Name,Generic Name,Composition,Dosage Form,Manufacturer\n"
        "010488,Augmentin 625mg Tablet,Amoxicillin + Clavulanate,"
        "Amoxicillin 500mg + Clavulanic Acid 125mg,Tablet,GSK Pakistan Limited\n"
        "002314,Panadol 500mg Tablet,,Paracetamol 500mg,Tablet,GSK\n"
    )
    records = DrapParser.parse_csv(csv_data)
    assert len(records) == 2
    assert records[0]["registration_id"] == "010488"
    assert records[0]["brand_name"] == "Augmentin 625mg Tablet"
    assert records[0]["generic_name"] == "Amoxicillin + Clavulanate"
    assert len(records[0]["ingredients"]) == 2

    assert records[1]["registration_id"] == "002314"
    assert records[1]["generic_name"] == "Paracetamol"
    assert len(records[1]["ingredients"]) == 1
    assert records[1]["ingredients"][0]["name"] == "Paracetamol"
