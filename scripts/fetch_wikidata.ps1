# scripts/fetch_wikidata.ps1
# Fetches real, verified attractions from Wikidata SPARQL across all global regions (CC0 1.0 Universal)
# Diverse category coverage: Historical, Nature, Religious, Adventure, Food, Shopping

$countries = @(
  @{ code = "IN"; name = "India"; qid = "wd:Q668" },
  @{ code = "FR"; name = "France"; qid = "wd:Q142" },
  @{ code = "IT"; name = "Italy"; qid = "wd:Q38" },
  @{ code = "US"; name = "United States"; qid = "wd:Q30" },
  @{ code = "JP"; name = "Japan"; qid = "wd:Q17" },
  @{ code = "GB"; name = "United Kingdom"; qid = "wd:Q145" },
  @{ code = "ES"; name = "Spain"; qid = "wd:Q29" },
  @{ code = "AE"; name = "United Arab Emirates"; qid = "wd:Q878" },
  @{ code = "AU"; name = "Australia"; qid = "wd:Q408" },
  @{ code = "BR"; name = "Brazil"; qid = "wd:Q155" },
  @{ code = "EG"; name = "Egypt"; qid = "wd:Q79" },
  @{ code = "SG"; name = "Singapore"; qid = "wd:Q334" },
  @{ code = "TR"; name = "Turkey"; qid = "wd:Q43" },
  @{ code = "DE"; name = "Germany"; qid = "wd:Q183" },
  @{ code = "GR"; name = "Greece"; qid = "wd:Q41" },
  @{ code = "CH"; name = "Switzerland"; qid = "wd:Q39" },
  @{ code = "NL"; name = "Netherlands"; qid = "wd:Q55" },
  @{ code = "PT"; name = "Portugal"; qid = "wd:Q45" },
  @{ code = "AT"; name = "Austria"; qid = "wd:Q40" },
  @{ code = "NO"; name = "Norway"; qid = "wd:Q20" },
  @{ code = "SE"; name = "Sweden"; qid = "wd:Q34" },
  @{ code = "IE"; name = "Ireland"; qid = "wd:Q27" },
  @{ code = "CZ"; name = "Czech Republic"; qid = "wd:Q213" },
  @{ code = "CA"; name = "Canada"; qid = "wd:Q16" },
  @{ code = "MX"; name = "Mexico"; qid = "wd:Q96" },
  @{ code = "CR"; name = "Costa Rica"; qid = "wd:Q800" },
  @{ code = "PE"; name = "Peru"; qid = "wd:Q419" },
  @{ code = "AR"; name = "Argentina"; qid = "wd:Q414" },
  @{ code = "CL"; name = "Chile"; qid = "wd:Q298" },
  @{ code = "CO"; name = "Colombia"; qid = "wd:Q739" },
  @{ code = "ZA"; name = "South Africa"; qid = "wd:Q258" },
  @{ code = "KE"; name = "Kenya"; qid = "wd:Q114" },
  @{ code = "MA"; name = "Morocco"; qid = "wd:Q1028" },
  @{ code = "TZ"; name = "Tanzania"; qid = "wd:Q924" },
  @{ code = "NZ"; name = "New Zealand"; qid = "wd:Q664" },
  @{ code = "CN"; name = "China"; qid = "wd:Q148" },
  @{ code = "ID"; name = "Indonesia"; qid = "wd:Q252" },
  @{ code = "TH"; name = "Thailand"; qid = "wd:Q869" },
  @{ code = "KR"; name = "South Korea"; qid = "wd:Q884" },
  @{ code = "VN"; name = "Vietnam"; qid = "wd:Q881" },
  @{ code = "MY"; name = "Malaysia"; qid = "wd:Q833" },
  @{ code = "NP"; name = "Nepal"; qid = "wd:Q837" },
  @{ code = "SA"; name = "Saudi Arabia"; qid = "wd:Q851" },
  @{ code = "JO"; name = "Jordan"; qid = "wd:Q810" },
  @{ code = "QA"; name = "Qatar"; qid = "wd:Q846" },
  @{ code = "OM"; name = "Oman"; qid = "wd:Q842" }
)

$categoryGroups = @(
  @{ name = "Historical"; types = "wd:Q570116 wd:Q33506 wd:Q4989906 wd:Q23413 wd:Q16560 wd:Q839954"; limit = 6 },
  @{ name = "Nature";     types = "wd:Q46169 wd:Q34038 wd:Q22698"; limit = 4 },
  @{ name = "Religious";  types = "wd:Q16970 wd:Q44539 wd:Q32815 wd:Q1755107 wd:Q44613"; limit = 4 },
  @{ name = "Adventure";  types = "wd:Q860861 wd:Q188055 wd:Q194195 wd:Q107649"; limit = 3 },
  @{ name = "ShoppingFood"; types = "wd:Q132510 wd:Q1128877 wd:Q175199 wd:Q11315"; limit = 3 }
)

Write-Host "Starting balanced extraction across $($countries.Count) countries..."
$allRecords = @()

foreach ($c in $countries) {
  $code = $c.code
  $name = $c.name
  $qid = $c.qid

  Write-Host "Querying $name ($code)..." -NoNewline
  $countBefore = $allRecords.Count

  foreach ($grp in $categoryGroups) {
    $types = $grp.types
    $lim = $grp.limit

    $sparql = @"
SELECT ?item ?name ?description ?coords ?type ?image WHERE {
  ?item wdt:P17 $qid;
        wdt:P31 ?type;
        rdfs:label ?name;
        wdt:P625 ?coords.
  FILTER(LANG(?name) = "en")
  VALUES ?type { $types }
  OPTIONAL { ?item wdt:P18 ?image. }
  OPTIONAL {
    ?item schema:description ?description.
    FILTER(LANG(?description) = "en")
  }
}
LIMIT $lim
"@

    $uri = "https://query.wikidata.org/sparql?query=" + [System.Uri]::EscapeDataString($sparql) + "&format=json"

    try {
      $res = Invoke-RestMethod -Uri $uri -Headers @{ "User-Agent" = "TourMateBot/1.0 (tourmate-tourism-guide; darsh@example.com)" } -TimeoutSec 10
      $bindings = $res.results.bindings

      foreach ($b in $bindings) {
        $allRecords += [PSCustomObject]@{
          wikidataId = $b.item.value.Split('/')[-1]
          name = $b.name.value
          description = if ($b.description) { $b.description.value } else { "" }
          coords = $b.coords.value
          type = $b.type.value.Split('/')[-1]
          image = if ($b.image) { $b.image.value } else { "" }
          country = $name
          countryCode = $code
        }
      }
    } catch {
      # Ignore transient timeout for specific subcategory
    }

    Start-Sleep -Milliseconds 150
  }

  $added = $allRecords.Count - $countBefore
  Write-Host " got $added records"
}

Write-Host "Total extracted records: $($allRecords.Count)"
$outPath = "assets/data/raw_wikidata_attractions.json"
$allRecords | ConvertTo-Json -Depth 4 | Set-Content -Path $outPath -Encoding utf8
Write-Host "Saved to $outPath"
