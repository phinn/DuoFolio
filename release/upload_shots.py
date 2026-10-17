#!/usr/bin/env python3
"""DuoFolio 6.7 寸截图上传(886×1920, APP_IPHONE_67)。四语同一套两张。"""
import sys, json, hashlib, struct
sys.path.insert(0, "/Users/phinn/Library/Application Support/KinetASCWatch/tools")
from asc_api import make_token
import requests

TOK = make_token()
HJ = {"Authorization": "Bearer " + TOK, "Content-Type": "application/json"}
HG = {"Authorization": "Bearer " + TOK}
BASE = "https://api.appstoreconnect.apple.com/v1"
VER = "284afc59-5d2c-4cb6-813a-a51d1bc3cb6d"

SHOTS = [
    "/Users/phinn/Documents/kinet/DuoFolio/release/screenshots/duofolio_67_main.png",
    "/Users/phinn/Documents/kinet/DuoFolio/release/screenshots/duofolio_67_laptop.png",
]
LOCALES = ["zh-Hans", "zh-Hant", "en-US", "ja"]
DISPLAY_TYPE = "APP_IPHONE_67"

def md5_b64(p):
    return __import__("base64").b64encode(hashlib.md5(open(p, "rb").read()).digest()).decode()

def get_json(url):
    return requests.get(url, headers=HG, timeout=30).json()

# 1. 拿四语 versionLocalization id
r = get_json(f"{BASE}/appStoreVersions/{VER}/appStoreVersionLocalizations")
vl = {x["attributes"]["locale"]: x["id"] for x in r["data"]}

for loc in LOCALES:
    lid = vl[loc]
    # 2. 找/建 set
    sets = get_json(f"{BASE}/appStoreVersionLocalizations/{lid}/appScreenshotSets?filter[screenshotDisplayType]={DISPLAY_TYPE}")
    if sets["data"]:
        sid = sets["data"][0]["id"]
    else:
        payload = {"data": {"type": "appScreenshotSets", "attributes": {"screenshotDisplayType": DISPLAY_TYPE},
                 "relationships": {"appStoreVersionLocalization": {"data": {"type": "appStoreVersionLocalizations", "id": lid}}}}}
        rr = requests.post(f"{BASE}/appScreenshotSets", headers=HJ, data=json.dumps(payload), timeout=30)
        if rr.status_code >= 300:
            print(loc, "set create", rr.status_code, rr.text[:200]); continue
        sid = rr.json()["data"]["id"]
    # 3. 清掉已有
    old = get_json(f"{BASE}/appScreenshotSets/{sid}/appScreenshots")
    for s in old["data"]:
        requests.delete(f"{BASE}/appScreenshots/{s['id']}", headers=HG, timeout=30)
    # 4. 上传两张
    for i, p in enumerate(SHOTS):
        fileName = p.split("/")[-1]
        size = __import__("os").path.getsize(p)
        payload = {"data": {"type": "appScreenshots",
            "attributes": {"fileName": fileName, "fileSize": size},
            "relationships": {"appScreenshotSet": {"data": {"type": "appScreenshotSets", "id": sid}}}}}
        rr = requests.post(f"{BASE}/appScreenshots", headers=HJ, data=json.dumps(payload), timeout=30)
        if rr.status_code >= 300:
            print(loc, "shot create", rr.status_code, rr.text[:300]); continue
        shot = rr.json()["data"]
        upops = get_json(f"{BASE}/appScreenshots/{shot['id']}/uploadOperations")["data"]
        for op in upops:
            with open(p, "rb") as f:
                data = f.read()
            part = data[op["offset"]: op["offset"] + op["length"]]
            pr = requests.put(op["url"], data=part, headers={"Content-Type": op["requestHeaders"].get("Content-Type", "application/octet-stream")}, timeout=120)
            print(loc, fileName, "PUT", pr.status_code)
        # commit
        cp = {"data": {"type": "appScreenshots", "id": shot["id"],
              "attributes": {"uploadedDate": __import__("datetime").datetime.now(__import__("datetime").timezone.utc).isoformat()},
              "relationships": {"appScreenshotSet": {"data": {"type": "appScreenshotSets", "id": sid}}}}}
        cr = requests.patch(f"{BASE}/appScreenshots/{shot['id']}", headers=HJ, data=json.dumps(cp), timeout=30)
        print(loc, fileName, "commit", cr.status_code)
print("DONE")
