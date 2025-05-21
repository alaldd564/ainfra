import requests

def get_coords_by_address(address, api_key):
    url = "https://apis.openapi.sk.com/tmap/geo/fullAddrGeo"
    headers = {"appKey": api_key}
    params = {"fullAddr": address}
    resp = requests.get(url, headers=headers, params=params)
    data = resp.json()
    if data.get("coordinateInfo") and data["coordinateInfo"].get("coordinate"):
        coord = data["coordinateInfo"]["coordinate"][0]
        return float(coord["newLat"]), float(coord["newLon"])
    else:
        print(f"'{address}'의 좌표를 찾을 수 없습니다.")
        return None, None

def get_tmap_route(start_lat, start_lon, end_lat, end_lon, api_key):
    url = "https://apis.openapi.sk.com/tmap/routes/pedestrian"
    headers = {"appKey": api_key, "Content-Type": "application/json"}
    payload = {
        "startX": str(start_lon), 
        "startY": str(start_lat),
        "endX": str(end_lon),
        "endY": str(end_lat),
        "reqCoordType": "WGS84GEO",
        "resCoordType": "WGS84GEO",
        "startName": "출발지",
        "endName": "도착지"
    }
    resp = requests.post(url, headers=headers, json=payload)
    return resp.json()

def main():
    api_key = "NsxOESGJ823yk2Nyvwcf15sSqaYMBXlw1L4UBmoa"  # 본인 Tmap API 키 입력
    origin = input("출발지를 입력하세요: ")
    destination = input("도착지를 입력하세요: ")

    start_lat, start_lon = get_coords_by_address(origin, api_key)
    end_lat, end_lon = get_coords_by_address(destination, api_key)
    if None in (start_lat, start_lon, end_lat, end_lon):
        print("좌표 변환에 실패했습니다.")
        return

    route = get_tmap_route(start_lat, start_lon, end_lat, end_lon, api_key)
    if "features" in route:
        print("\n--- 길안내 ---")
        for feature in route["features"]:
            if feature["geometry"]["type"] == "LineString":
                continue
            desc = feature["properties"].get("description")
            if desc:
                print("-", desc)
    else:
        print("길안내 정보를 가져오지 못했습니다.")

if __name__ == "__main__":
    main()
