"""Stage the runtime discovery layers used by Android's WorldMap on iOS."""

GROUPS = {
    "essential": (13.2, [(14.5, 12), (16, 36), (17.5, 100), (18.6, 999)], 2,
                  ["restaurant", "fast_food", "ice_cream", "bakery", "butcher", "cafe", "lodging", "hospital", "clinic", "pharmacy"]),
    "utility": (14, [(15.5, 35), (17.5, 120), (18.6, 999)], 10, ["fuel", "charging_station", "parking"]),
    "discovery": (14.2, [(15.5, 10), (16.8, 24), (17.8, 45), (18.6, 999)], 4,
                  ["shop", "grocery", "alcohol_shop", "clothing_store", "mall", "bank", "attraction", "art_gallery", "castle", "museum", "park", "garden", "playground", "library", "monument", "cinema", "theatre", "atm"]),
    "community": (14.8, [(16, 8), (17.5, 25), (18.6, 999)], 3,
                  ["school", "college", "university", "kindergarten", "town_hall", "post", "police", "fire_station", "place_of_worship", "stadium", "sports_centre", "railway", "bus", "ferry_terminal"]),
    "support": (17.8, [(18.6, 999)], 20, ["information", "toilets", "drinking_water", "car", "office", "music"]),
    "social": (14.8, [(17.5, 160), (18.6, 999)], 80, ["bar", "beer"]),
}
ICONS = {
    "education": ["school", "college", "university", "kindergarten"], "pub": ["bar", "beer"],
    "cafe": ["cafe"], "food": ["restaurant", "fast_food", "ice_cream", "bakery", "butcher"],
    "stay": ["lodging"], "fuel": ["fuel", "charging_station"], "parking": ["parking"],
    "health": ["hospital", "pharmacy", "clinic"],
    "sights": ["attraction", "art_gallery", "castle", "museum", "library", "monument", "cinema", "theatre"],
    "nature": ["park", "garden", "playground"], "cash": ["atm", "bank"],
    "shop": ["shop", "grocery", "alcohol_shop", "clothing_store", "mall"],
}


def add_discovery_layers(style, world, poi_scale=.55, light_labels=None):
    font = next(layer["layout"]["text-font"] for layer in style["layers"] if "text-font" in layer.get("layout", {}))
    icon = ["case"]
    for kind, classes in ICONS.items():
        predicate = ["in", ["get", "class"], ["literal", classes]]
        subclass = {"pub": "pub", "fuel": "fuel", "health": "pharmacy"}.get(kind)
        if subclass:
            predicate = ["any", predicate, ["==", ["get", "subclass"], subclass]]
        icon += [predicate, "poi-" + kind]
    icon += ["poi-place"]
    light = light_labels if light_labels is not None else world not in {"old_west", "san_andreas", "rivia", "ctos", "lands_between", "ghost", "kingdom", "mafia"}
    all_classes = sum((value[3] for value in GROUPS.values()), [])
    groups = {"other": (18.6, [], 999, [])} | GROUPS
    for name, (minimum, stops, initial, classes) in groups.items():
        classification = ["in", ["get", "class"], ["literal", classes]] if classes else ["!", ["in", ["get", "class"], ["literal", all_classes]]]
        if name == "social":
            classification = ["any", classification, ["==", ["get", "subclass"], "pub"]]
        if name == "other":
            classification = ["all", classification, ["!=", ["get", "subclass"], "pub"]]
        rank = ["step", ["zoom"], initial]
        for zoom, limit in stops:
            rank += [zoom, limit]
        predicate = classification if not stops else ["all", classification, ["<=", ["coalesce", ["get", "rank"], 0], rank]]
        style["layers"].append({
            "id": "waypoint-" + name + "-places", "type": "symbol", "source": "openmaptiles", "source-layer": "poi", "minzoom": minimum,
            "filter": predicate,
            "layout": {"icon-image": icon, "icon-size": (0.9 if name != "other" else 0.8) * poi_scale / .55, "icon-allow-overlap": False, "icon-padding": 5,
                       "text-font": font, "text-field": ["step", ["zoom"], "", 17.2, ["coalesce", ["get", "name:en"], ["get", "name_en"], ["get", "name"], ""]],
                       "text-size": 10, "text-optional": True, "text-offset": [0, 2]},
            "paint": {"text-color": "#EEEEDF" if light else "#282E26", "text-halo-color": "#18201C" if light else "#E3DABF", "text-halo-width": 1.5}
        })
