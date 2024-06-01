import requests
import re

current_version = 720

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


def main():
    global current_version

    # 获取最新版本号
    latest_version = requests.get(BASE_URL + "latest").text.strip()
    print(f"Latest version: {latest_version}")

    if latest_version != str(current_version):
        print("Updating files...")
        for filename in files_to_download:
            download_file(latest_version, filename)

        update_splatdatabase_swift(latest_version)
        update_script_version(latest_version)

        print("Files updated successfully.")
    else:
        print("No update needed.")


if __name__ == "__main__":
    main()
