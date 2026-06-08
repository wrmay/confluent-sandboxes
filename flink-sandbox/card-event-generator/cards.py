from typing import Dict, Any, Tuple, List
import faker
import re


def encode_card_name(input: str)->str:
    result = input.split()[0]
    match result:
        case "Diners":
            result = "Diners_Club"
        case "American":
            result = "American_Express"

    return result

# 
# Represent this as the last 
#
def encode_expiration(input: str) -> Tuple[int, int]:
    words = input.split('/')
    month = int(words[0])
    year = int(words[1])
    return year, month

CVC_REGEX = re.compile(r'^\w+:\s*(\w+)')

def encode_verification(input: str)->str:
    match = CVC_REGEX.match(input)
    result = match.group(1)
    return result

def build_card(input: str) -> Dict[str, Any]:
    result = dict()
    lines = input.splitlines()
    result["provider"] = encode_card_name(lines[0])
    result["cardholder_name"] = lines[1]

    words = lines[2].split()
    result["card_number"] = words[0]

    year, month = encode_expiration(words[1])
    expiration = dict()
    expiration["year"] = year
    expiration["month"] = month
    result["expiration"] = expiration
    result["verification_code"] = encode_verification(lines[3])
    return result

def fake_cards(count: int)->List[Dict[str, Any]]:
    generator = faker.Faker()
    result = [build_card(generator.credit_card_full()) for _ in range(count)]
    return result

if __name__ == '__main__':
    cards = fake_cards(20)
    print(cards)