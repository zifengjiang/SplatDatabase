import requests
import json
import re

current_version = 1010

BASE_URL = "https://raw.githubusercontent.com/Leanny/splat3/main/data/mush/"

files_to_download = [
    "BadgeInfo.json",
    "CoopEnemyInfo.json",
    "CoopSceneInfo.json",
    "CoopSkinInfo.json",
    "GearInfoClothes.json",
    "GearInfoHead.json",
    "GearInfoShoes.json",
    "NamePlateBgInfo.json",
    "VersusSceneInfo.json",
    "WeaponInfoMain.json",
    "WeaponInfoSub.json",
]


def download_file(version, filename):
    url = f"{BASE_URL}{version}/{filename}"
    response = requests.get(url)
    if response.status_code == 200:
        with open(f"Sources/SplatDatabase/Resources/{filename}", "wb") as file:
            file.write(response.content)
    else:
        print(f"Failed to download {filename} from {url}")


def update_splatdatabase_swift(version):
    # 更新SplatDatabase.swift文件
    with open("Sources/SplatDatabase/SplatDatabase.swift", "r") as file:
        content = file.read()

    migration_code = f"""
    migrator.registerMigration("insertI18nForVersion{version}") {{ db in
        try self.updateI18n(db: db)
    }}

    migrator.registerMigration("insertImageMapForVersion{version}") {{ db in
        try self.updateImageMap(db: db)
    }}
    return migrator
    """

    updated_content = re.sub(r'return migrator', migration_code, content)

    with open("Sources/SplatDatabase/SplatDatabase.swift", "w") as file:
        file.write(updated_content)


def update_script_version(new_version):
    # 更新脚本中的 current_version
    with open(__file__, "r") as file:
        content = file.read()

    updated_content = re.sub(r'current_version = \d+',
                             f'current_version = {new_version}', content)

    with open(__file__, "w") as file:
        file.write(updated_content)


def write_out(path, obj):
    with open(path, 'w', encoding='utf-8') as file:
        json.dump(obj, file, ensure_ascii=False, indent=2)
        file.write("\n")


def build_trie(array):
    trie = {}
    for obj in array:
        node = trie
        for char in obj["key"]:
            if char not in node:
                node[char] = {}
            node = node[char]
        if "tags" not in node:
            node["tags"] = []
        node["tags"].append(obj["value"])
    return trie


def get_title_map():
    urls = [
        "https://raw.githubusercontent.com/Leanny/splat3/main/data/language/CNzh_unicode.json",
        "https://raw.githubusercontent.com/Leanny/splat3/main/data/language/EUde_unicode.json",
        "https://raw.githubusercontent.com/Leanny/splat3/main/data/language/EUen_unicode.json",
        "https://raw.githubusercontent.com/Leanny/splat3/main/data/language/EUes_unicode.json",
        "https://raw.githubusercontent.com/Leanny/splat3/main/data/language/EUfr_unicode.json",
        "https://raw.githubusercontent.com/Leanny/splat3/main/data/language/EUit_unicode.json",
        "https://raw.githubusercontent.com/Leanny/splat3/main/data/language/EUnl_unicode.json",
        "https://raw.githubusercontent.com/Leanny/splat3/main/data/language/EUru_unicode.json",
        "https://raw.githubusercontent.com/Leanny/splat3/main/data/language/JPja_unicode.json",
        "https://raw.githubusercontent.com/Leanny/splat3/main/data/language/KRko_unicode.json",
        "https://raw.githubusercontent.com/Leanny/splat3/main/data/language/TWzh_unicode.json",
        "https://raw.githubusercontent.com/Leanny/splat3/main/data/language/USen_unicode.json",
        "https://raw.githubusercontent.com/Leanny/splat3/main/data/language/USes_unicode.json",
        "https://raw.githubusercontent.com/Leanny/splat3/main/data/language/USfr_unicode.json"
    ]

    responses = [requests.get(url) for url in urls]
    jsons = [res.json() for res in responses]

    adjectives = []
    subjects = []

    for i, json_data in enumerate(jsons):
        for key, value in json_data["CommonMsg/Byname/BynameAdjective"].items():
            id = f"TitleAdjective-{key}"
            adjectives.append({
                "key": re.sub(r"\[.+?\]", "", value),
                "value": {
                    "id": id,
                    "index": i,
                }
            })

        subject = {}
        for key, value in json_data["CommonMsg/Byname/BynameSubject"].items():
            if key.endswith("_0"):
                neutral_key = key.replace("_0", "")
                alt_key = f"{neutral_key}_1"
                if "group=0001" in json_data["CommonMsg/Byname/BynameSubject"].get(alt_key, ""):
                    id = f"TitleSubject-{neutral_key}"
                    subject[re.sub(r"\[.+?\]", "", value)] = id
                else:
                    id = f"TitleSubject-{key}"
                    subject[re.sub(r"\[.+?\]", "", value)] = id
                    alt_id = f"TitleSubject-{alt_key}"
                    subject[re.sub(r"\[.+?\]", "", json_data["CommonMsg/Byname/BynameSubject"]
                            [alt_key])] = alt_id

        subjects.append(subject)

    return {"adjectives": build_trie(adjectives), "subjects": subjects}


def main():
    global current_version
    # 获取最新版本号
    latest_version = requests.get(BASE_URL + "latest").text.strip()
    print(f"Latest version: {latest_version}")

    if latest_version != str(current_version):
        print("Updating files...")

        # 更新 titles.json
        title_map = get_title_map()
        write_out("Sources/SplatDatabase/Resources/titles.json", title_map)

        for filename in files_to_download:
            download_file(latest_version, filename)

        update_splatdatabase_swift(latest_version)
        update_script_version(latest_version)

        print("Files updated successfully.")
    else:
        print("No update needed.")


if __name__ == "__main__":
    main()
