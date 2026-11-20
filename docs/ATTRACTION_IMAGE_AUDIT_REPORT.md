# TourMate — Attraction Image Audit & Validation Report

**Date:** 2026-11-20T11:50:16.747649  
**Target Dataset:** `assets/data/global_attractions.json`  
**Total Attractions Examined:** 829  

---

## 1. Audit Executive Summary

| Metric | Count | Percentage |
|---|---|---|
| **Total Attractions** | 829 | 100.0% |
| **Valid Direct Image URLs (HTTP 200 OK)** | 779 | 94.0% |
| **Graceful Fallbacks (Missing Photographs)** | 50 | 6.0% |
| **Broken Image URLs** | 0 | 0.0% |
| **Unique Image URLs** | 760 | - |
| **Duplicate Image URLs** | 17 | - |

---

## 2. Image Source Domains

| Domain | Count | CORS Support | CDN Type |
|---|---|---|---|
| `thumb.wikimedia.org` | 653 | Yes (`*`) | Wikimedia Global Edge / Fastly |
| `upload.wikimedia.org` | 126 | Yes (`*`) | Wikimedia Global Edge / Fastly |

---

## 3. Licensing & Attribution Distribution

| License | Count | Distribution |
|---|---|---|
| CC BY-SA 3.0 | 239 | 30.7% |
| CC BY-SA 4.0 | 208 | 26.7% |
| Public domain | 109 | 14.0% |
| CC BY 2.0 | 45 | 5.8% |
| CC BY-SA 2.0 | 43 | 5.5% |
| CC BY 3.0 | 29 | 3.7% |
| CC0 | 23 | 3.0% |
| CC BY 2.5 | 16 | 2.1% |
| CC BY-SA 2.5 | 13 | 1.7% |
| CC BY 4.0 | 11 | 1.4% |
| Copyrighted free use | 7 | 0.9% |
| FAL | 6 | 0.8% |

---

## 4. Graceful Fallbacks (No Verifiable Image)

The following 50 attractions do not have a confirmed, verifiable photograph on Wikimedia Commons.
In accordance with project safety guidelines, no unrelated or stock photos were used. These render graceful category-based fallback illustrations:

| ID | Name | Location | Category |
|---|---|---|---|
| `in-sacred-heart-forane-church` | Sacred Heart Forane Church | Kozhikode, India | Religious |
| `in-siege-of-fatehgarh` | Siege of Fatehgarh | Fatehgarh, India | Adventure |
| `in-mall-of-mysore` | Mall of Mysore | Mysuru, India | Shopping |
| `in-smart-bazaar` | Smart Bazaar | Rourkela, India | Shopping |
| `us-foxstone-park` | Foxstone Park | Vienna, United States | Nature |
| `ae-ad-dur` | Ad-Dur | Umm Al Quwain, United Arab Emirates | Historical |
| `ae-universal-studios-dubailand` | Universal Studios Dubailand | Dubai, United Arab Emirates | Adventure |
| `gr-veikos-grove` | Veikos Grove | Athens, Greece | Nature |
| `ch-conny-land` | Conny-Land | Lipperswil, Switzerland | Adventure |
| `ch-massacre-of-greifensee` | Massacre of Greifensee | Zurich, Switzerland | Adventure |
| `nl-burg-upladen` | Burg Upladen | Upladen / Montferland, Netherlands | Historical |
| `se-august-spngbergs-park` | August Spångbergs Park | Degerfors, Sweden | Nature |
| `se-land-zoo-and-amusement-park` | Öland Zoo and Amusement Park | Färjestaden, Sweden | Adventure |
| `mx-santiago-apstol-parish-in-tequixquiac` | Santiago Apóstol parish in Tequixquiac | Tequixquiac, Mexico | Religious |
| `cr-palmar-sur-archeological-excavations` | Palmar Sur Archeological Excavations | Palmar Sur, Costa Rica | Historical |
| `cr-museo-de-ciencias-naturales-la-salle` | Museo de Ciencias Naturales La Salle | San José, Costa Rica | Historical |
| `pe-calipuy-national-reserve` | Calipuy National Reserve | Santiago de Chuco, Peru | Nature |
| `pe-open-plaza-los-jardines` | Open Plaza Los Jardines | Trujillo, Peru | Shopping |
| `ar-abada-del-nio-dios` | Abadía del Niño Dios | Victoria, Argentina | Religious |
| `cl-siege-of-concepcion` | Siege of Concepcion | Concepción, Chile | Adventure |
| `co-international-charismatic-mission-church` | International Charismatic Mission Church | Bogotá, Colombia | Religious |
| `co-1980-dominican-embassy-siege-in-bogot` | 1980 Dominican Embassy Siege in Bogotá | Bogotá, Colombia | Adventure |
| `za-cresta-shopping-centre` | Cresta Shopping Centre | Johannesburg, South Africa | Shopping |
| `ke-mosque-of-jesus-christ-son-of-mary` | Mosque of Jesus Christ Son of Mary | Kisumu, Kenya | Religious |
| `ke-the-hub-karen-mall` | The Hub Karen Mall | Nairobi, Kenya | Shopping |
| `ma-al-mazar-commercial-centre` | Al Mazar Commercial Centre | Marrakech, Morocco | Shopping |
| `tz-hanga-abbey` | Hanga Abbey | Namtumbo (Ruvuma), Tanzania | Religious |
| `tz-ndanda-abbey` | Ndanda Abbey | Masasi (Mtwara), Tanzania | Religious |
| `tz-rock-city-mall` | Rock City Mall | Mwanza, Tanzania | Shopping |
| `nz-hukutaia-domain-recreation-reserve` | Hukutaia Domain Recreation Reserve | Opotiki, New Zealand | Nature |
| ... and 20 more | see `docs/MISSING_PHOTOGRAPHS.txt` | | |

---

## 5. Sample Verified Attraction Photographs

| Attraction | City, Country | License | Direct Thumbnail URL |
|---|---|---|---|
| **Mysore Palace** | Mysuru, India | GFDL 1.2 | [View Image](https://thumb.wikimedia.org/wikipedia/commons/thumb/a/a4/Mysore_Palace_Morning.jpg/960px-Mysore_Palace_Morning.jpg) |
| **Amber Fort** | Jaipur, India | FAL | [View Image](https://thumb.wikimedia.org/wikipedia/commons/thumb/e/e5/Jaipur_03-2016_04_Amber_Fort.jpg/960px-Jaipur_03-2016_04_Amber_Fort.jpg) |
| **Hawa Mahal** | Jaipur, India | CC BY-SA 4.0 | [View Image](https://thumb.wikimedia.org/wikipedia/commons/thumb/4/41/East_facade_Hawa_Mahal_Jaipur_from_ground_level_%28July_2022%29_-_img_01.jpg/960px-East_facade_Hawa_Mahal_Jaipur_from_ground_level_%28July_2022%29_-_img_01.jpg) |
| **Lumbini Park** | Hyderabad, India | CC BY-SA 4.0 | [View Image](https://thumb.wikimedia.org/wikipedia/commons/thumb/c/c2/Lumbini_Park%2C_Hyderabad.jpg/960px-Lumbini_Park%2C_Hyderabad.jpg) |
| **Madhav National Park** | Shivpuri, India | CC BY-SA 4.0 | [View Image](https://thumb.wikimedia.org/wikipedia/commons/thumb/3/3d/Madhav_Natioinal_Park.JPG/960px-Madhav_Natioinal_Park.JPG) |
| **Madhav National Park** | Shivpuri, India | CC BY-SA 4.0 | [View Image](https://thumb.wikimedia.org/wikipedia/commons/thumb/3/3d/Madhav_Natioinal_Park.JPG/960px-Madhav_Natioinal_Park.JPG) |
| **Tadoba-Andhari Tiger Reserve** | Chandrapur, India | CC BY-SA 3.0 | [View Image](https://thumb.wikimedia.org/wikipedia/commons/thumb/5/57/Tiger_at_Tadoba.jpg/960px-Tiger_at_Tadoba.jpg) |
| **Vimala Temple** | Puri, India | Public domain | [View Image](https://upload.wikimedia.org/wikipedia/commons/f/fd/Minor_temples_in_Jagannath_Puri.jpg) |
| **Ajanta Caves** | Aurangabad, India | CC BY 2.5 | [View Image](https://thumb.wikimedia.org/wikipedia/commons/thumb/c/c3/Ajanta_%2863%29.jpg/960px-Ajanta_%2863%29.jpg) |
| **St. Andrew's Church, Chennai** | Chennai, India | CC BY-SA 3.0 | [View Image](https://thumb.wikimedia.org/wikipedia/commons/thumb/0/04/St_Andrews_Church_-_The_Kirk.jpg/960px-St_Andrews_Church_-_The_Kirk.jpg) |
| **Siege of Cawnpore** | Kanpur, India | CC0 | [View Image](https://thumb.wikimedia.org/wikipedia/commons/thumb/a/a1/Massacre_in_the_boats_off_Cawnpore_-_The_history_of_the_Indian_Mutiny_%281858-1859%29%2C_opposite_336_-_BL.jpg/960px-Massacre_in_the_boats_off_Cawnpore_-_The_history_of_the_Indian_Mutiny_%281858-1859%29%2C_opposite_336_-_BL.jpg) |
| **Siege of Cawnpore** | Kanpur, India | CC0 | [View Image](https://thumb.wikimedia.org/wikipedia/commons/thumb/a/a1/Massacre_in_the_boats_off_Cawnpore_-_The_history_of_the_Indian_Mutiny_%281858-1859%29%2C_opposite_336_-_BL.jpg/960px-Massacre_in_the_boats_off_Cawnpore_-_The_history_of_the_Indian_Mutiny_%281858-1859%29%2C_opposite_336_-_BL.jpg) |
| **Ampa Skywalk** | Chennai, India | CC BY-SA 2.0 | [View Image](https://thumb.wikimedia.org/wikipedia/commons/thumb/7/72/Ampa_Mall_4.jpg/960px-Ampa_Mall_4.jpg) |
| **Palais des Papes** | Avignon, France | CC BY-SA 4.0 | [View Image](https://thumb.wikimedia.org/wikipedia/commons/thumb/a/a9/00_0711_Avignon_%28Frankreich%29_-_Kathetrale_und_Papstpalast.jpg/960px-00_0711_Avignon_%28Frankreich%29_-_Kathetrale_und_Papstpalast.jpg) |
| **Tuileries Palace** | Paris, France | Public domain | [View Image](https://upload.wikimedia.org/wikipedia/commons/e/eb/Tuileries_jardin_1867.jpg) |

