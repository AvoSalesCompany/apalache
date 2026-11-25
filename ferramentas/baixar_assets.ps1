# Baixa modelos e texturas CC0 do Poly Haven (polyhaven.com) para jogo/assets.
# Pode ser rodado de novo sem problema: pula o que ja existe.
$ErrorActionPreference = 'Continue'
[Net.ServicePointManager]::SecurityProtocol = 'Tls12'
$raiz = Split-Path -Parent $PSScriptRoot
$h = @{ 'User-Agent' = 'generic-client' }

$modelos = 'shrub_02','shrub_03','shrub_04',
  'dead_tree_trunk','dead_tree_trunk_02','tree_stump_01','tree_stump_02','root_cluster_01',
  'rock_moss_set_01','rock_moss_set_02','boulder_01','rock_09','dry_branches_medium_01',
  'vintage_radio_transceiver','wooden_lantern_01','WoodenTable_01','WoodenChair_01','old_bed_frame',
  'barrel_stove','painted_wooden_cabinet','wooden_axe','Rockingchair_01','wooden_crate_01',
  'bolt_action_rifle_7_62','metal_jerrycan','portable_generator','wooden_bookshelf_worn','vintage_oil_lamp','pot_enamel_01',
  'wooden_bucket_01','wine_barrel_01','mantel_clock_01','carved_wooden_plate','ArmChair_01',
  'stone_fire_pit','metal_trash_can','Barrel_01'

# id -> resolucao
$texturas = [ordered]@{
  'forest_leaves_02'='2k'; 'brown_mud_leaves_01'='2k'; 'mossy_rock'='2k';
  'river_small_rocks'='2k'; 'gravel_ground_01'='1k';
  'bark_brown_02'='1k'; 'pine_bark'='1k'; 'bark_willow_02'='1k';
  'weathered_brown_planks'='2k'; 'weathered_planks'='1k'; 'rusty_metal_02'='1k'; 'rusty_corrugated_iron'='1k';
  'green_metal_rust'='1k'; 'concrete_moss'='1k'; 'fabric_pattern_07'='1k'; 'dirty_carpet'='1k'; 'blue_metal_plate'='1k';
  'snow_02'='2k'; 'snow_floor'='2k'
}

function Baixar($url, $dest) {
  if (Test-Path -LiteralPath $dest) { return }
  $d = Split-Path -Parent $dest
  if (-not (Test-Path -LiteralPath $d)) { New-Item -ItemType Directory -Force $d | Out-Null }
  curl.exe -sSL --retry 3 -A 'generic-client' -o $dest $url
}

foreach ($m in $modelos) {
  try {
    $f = Invoke-RestMethod -UseBasicParsing -Headers $h "https://api.polyhaven.com/files/$m"
    $g = $f.gltf.'1k'.gltf
    $pasta = Join-Path $raiz "jogo\mod"
    $gl = Join-Path $pasta "$m.gltf"; Baixar $g.url $gl; [IO.File]::WriteAllText($gl, ([IO.File]::ReadAllText($gl)).Replace("textures/", "").Replace("bolt_action_rifle_7_62_accesories_nor_gl_1k.jpg", "rifle_acc_nor.jpg"))
    foreach ($p in $g.include.PSObject.Properties) {
      $rel = Split-Path -Leaf ($p.Name -replace '/', '\')
      $rel = $rel.Replace('bolt_action_rifle_7_62_accesories_nor_gl_1k.jpg', 'rifle_acc_nor.jpg'); if ($rel -match '\.\.' -or $rel -match ':') { "caminho recusado: $rel"; continue }
      Baixar $p.Value.url (Join-Path $pasta $rel)
    }
    "modelo ok: $m"
  } catch { "modelo FALHOU: $m  $($_.Exception.Message)" }
}

foreach ($t in $texturas.Keys) {
  try {
    $r = $texturas[$t]
    $f = Invoke-RestMethod -UseBasicParsing -Headers $h "https://api.polyhaven.com/files/$t"
    $pasta = Join-Path $raiz 'jogo\tex'
    $cor = $f.Diffuse; if (-not $cor) { $cor = ($f.PSObject.Properties | Where-Object { $_.Name -match "^col|diff" } | Select-Object -First 1).Value }; Baixar $cor.$r.jpg.url (Join-Path $pasta "${t}_cor.jpg")
    Baixar $f.nor_gl.$r.jpg.url  (Join-Path $pasta "${t}_nor.jpg")
    if ($f.arm) { Baixar $f.arm.$r.jpg.url (Join-Path $pasta "${t}_arm.jpg") }
    else { Baixar $f.Rough.$r.jpg.url (Join-Path $pasta "${t}_arm.jpg") }
    "textura ok: $t"
  } catch { "textura FALHOU: $t  $($_.Exception.Message)" }
}

$mb = (Get-ChildItem (Join-Path $raiz 'jogo\mod') -Recurse -File | Measure-Object Length -Sum).Sum / 1MB
"TOTAL: {0:N1} MB" -f $mb
