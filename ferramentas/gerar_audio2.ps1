# Sons e vozes da versao 0.3 (neve, vila, torre). Usa o sintetizador de gerar_audio.ps1.
# Vozes: Microsoft Daniel e Maria (do Windows), provisorias.
param([switch]$SoVozes, [switch]$SoSons)
$raiz = Split-Path -Parent $PSScriptRoot
$saida = Join-Path $raiz 'jogo\som'
$src = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'gerar_audio.ps1'))
$a = $src.IndexOf("-TypeDefinition @'") + 18
$b = $src.IndexOf("'@", $a)
$cs = $src.Substring($a, $b - $a).Trim()
$novo = @"
  static double[] PNeve() {
    double[] o = Graos(.34, 260, 900, 4200, .12);
    double[] c = Fil(Branco(.34), BP, U(1500, 2200), 1.2);
    for (int i = 0; i < c.Length; i++) { double t = i / (double)SR; c[i] *= Math.Exp(-Math.Pow((t - .09) / .06, 2)) * (0.6 + 0.4 * Math.Sin(t * U(600, 640))); }
    Mix(o, c, 0, .9); Mix(o, Graos(.26, 120, 250, 900, .10), .02, .9); Mix(o, Batida(58, .03), 0, .35);
    Mix(o, Graos(.16, 60, 1600, 5200, .06), .15, .6);
    return Fil(o, LP, 6500, .7);
  }
  static double[] Voz(double s, double f0, double f1, double[] fm, double rasp, double vib) {
    double[] o = Buf(s); double ph = 0; int n = fm.Length; Bq[] bq = new Bq[n]; for (int k = 0; k < n; k++) bq[k] = new Bq(BP, fm[k], 7);
    for (int i = 0; i < o.Length; i++) { double t = i / (double)SR, u = t / s; double f = f0 + (f1 - f0) * Math.Sin(Math.PI * Math.Min(1, u * 1.05)) + vib * Math.Sin(t * 41); ph += f / SR; double x = 2 * (ph - Math.Floor(ph)) - 1; x = x * (1 - rasp) + N() * rasp * (0.5 + 0.5 * Math.Sin(t * 180)); double y = 0; for (int k = 0; k < n; k++) y += bq[k].P(x) * (1.0 - .18 * k); o[i] = y; }
    return o;
  }
  static double[] Env(double[] a, double at, double de) { for (int i = 0; i < a.Length; i++) { double t = i / (double)SR, T = a.Length / (double)SR; a[i] *= Math.Min(1, t / at) * Math.Min(1, (T - t) / de); } return a; }
  static double[] Corvo() {
    double[] o = Buf(1.5); int q = R.Next(1, 4); double em = .02, f = U(430, 540);
    for (int k = 0; k < q; k++) { double d = U(.22, .34); double[] c = Env(Voz(d, f * .86, f * 1.12, new double[] { 1150, 1750, 2700 }, .55, 14), .02, .10); Mix(o, Sat(Norm(c, 1), 2.2), em, .8); em += d + U(.06, .16); }
    return Rev(o, 1.2, .25, 1.4);
  }
  static double[] Asas(double s, int passaros) {
    double[] o = Buf(s);
    for (int p = 0; p < passaros; p++) { double em = U(0, .9), hz = U(13, 19), fim = U(s * .5, s), g = U(.4, 1); Bq bq = new Bq(BP, U(380, 1300), 1.1); 
      for (double t0 = em; t0 < fim; t0 += 1 / hz) { double[] w = Buf(.05); double k = g * Math.Exp(-(t0 - em) / (s * .42)); for (int i = 0; i < w.Length; i++) { double t = i / (double)SR; w[i] = bq.P(N()) * Math.Sin(Math.PI * t / .05) * k; } Mix(o, w, t0 + U(-.004, .004), 1); } }
    return o;
  }
  static double[] Caes(double s) {
    double[] o = Buf(s);
    for (int d = 0; d < 3; d++) { double f = U(260, 460), em = U(0, 1.2); while (em < s - .4) { int q = R.Next(1, 4); for (int k = 0; k < q && em < s - .4; k++) { double[] c = Env(Voz(.15, f * .8, f * 1.5, new double[] { 620, 1150, 2100 }, .4, 5), .008, .08); Mix(o, Sat(Norm(c, 1), 2.0), em, U(.4, .8)); em += U(.2, .3); } em += U(.25, 1.3); } }
    return Fil(Rev(o, 1.8, .45, 1.6), LP, 2600, .7);
  }
  static double[] GritoGente() {
    double[] o = Buf(2.4); double[] v = Env(Voz(1.7, 560, 980, new double[] { 880, 1420, 2700, 3600 }, .22, 26), .05, .5);
    Mix(o, Sat(Norm(v, 1), 2.6), .02, .9); double[] r = Env(Fil(Branco(1.6), BP, 2300, 1.4), .1, .6); Mix(o, r, .05, .18); return Rev(o, 2.2, .35, 1.8);
  }
  static double[] Tiro() {
    double[] o = Buf(3.2); double[] c = Branco(.02); for (int i = 0; i < c.Length; i++) c[i] *= Math.Exp(-i / (.003 * SR)); Mix(o, c, 0, 2.2);
    double[] m = Fil(Branco(.5), LP, 1500, .8); for (int i = 0; i < m.Length; i++) m[i] *= Math.Exp(-i / (.055 * SR)); Mix(o, m, 0, 2.4);
    Mix(o, Batida(52, .07), 0, 1.6); Mix(o, Batida(95, .03), 0, 1.0);
    double[] t = Fil(Branco(2.4), LP, 700, .7); for (int i = 0; i < t.Length; i++) t[i] *= Math.Exp(-i / (.55 * SR)) * (.6 + .4 * Math.Sin(i / 2600.0)); Mix(o, t, .03, .8);
    return Sat(Norm(Rev(o, 2.6, .35, 2.0), 1), 1.7);
  }
  static double[] Clique(double s, double f, double d) { double[] o = Reson(s, new double[] { f, f * 1.7, f * 2.9, f * 4.3 }, d, .5); double[] c = Branco(.006); Mix(o, c, 0, .6); return o; }
  static double[] Ferrolho() { double[] o = Buf(.85); Mix(o, Clique(.2, 820, .02), .0, .7); Mix(o, Fil(Branco(.14), BP, 2600, 1.0), .07, .22); Mix(o, Clique(.25, 560, .03), .20, 1); Mix(o, Fil(Branco(.12), BP, 3000, 1.0), .36, .2); Mix(o, Clique(.25, 640, .03), .48, 1.1); Mix(o, Clique(.15, 1100, .015), .58, .6); return o; }
  static double[] Sirene(double s) { double[] o = Buf(s); double ph = 0; for (int i = 0; i < o.Length; i++) { double t = i / (double)SR; double w = .5 - .5 * Math.Cos(2 * Math.PI * t / 4.0); double f = 560 + 780 * w; ph += f / SR; double x = Math.Sin(2 * Math.PI * ph) + .4 * Math.Sin(4 * Math.PI * ph) + .25 * Math.Sign(Math.Sin(2 * Math.PI * ph)); o[i] = x * .4; } return Fil(o, LP, 2600, .7); }
  static double[] Motor(double s) { double[] o = Buf(s); Bq l = new Bq(LP, 420, .8), h = new Bq(BP, 1500, .8); double ph = 0; for (int i = 0; i < o.Length; i++) { double t = i / (double)SR; ph += (27.0 + .4 * Math.Sin(t * 3.1)) / SR; double u = ph - Math.Floor(ph); double p = Math.Exp(-u * 9) * (N() * .5 + Math.Sin(2 * Math.PI * u * 3)); o[i] = l.P(p) * 2.2 + h.P(N()) * .16 * (.5 + .5 * Math.Exp(-u * 5)); } return o; }
  static double[] Partida() { double[] o = Buf(1.1); double[] z = Fil(Branco(.4), BP, 1100, 1.2); for (int i = 0; i < z.Length; i++) { double t = i / (double)SR; z[i] *= Math.Sin(Math.PI * t / .4) * (.6 + .4 * Math.Sin(t * 420)); } Mix(o, z, 0, .7); for (int k = 0; k < 4; k++) { double[] p = Fil(Branco(.12), LP, 500, .8); for (int i = 0; i < p.Length; i++) p[i] *= Math.Exp(-i / (.03 * SR)); Mix(o, p, .28 + k * .13, 1.6 - k * .25); Mix(o, Batida(60, .03), .28 + k * .13, .8 - k * .12); } return o; }
  static double[] Despeja(double s) { double[] o = Buf(s); Bq b = new Bq(BP, 700, 3); for (int i = 0; i < o.Length; i++) { double t = i / (double)SR; if (i % 900 == 0) b.Set(BP, U(350, 1300), U(2, 6)); o[i] = b.P(N()) * (.5 + .5 * Math.Sin(t * 23 + Math.Sin(t * 7) * 3)); } return Env(o, .2, .4); }
  static double[] Nojo() { double[] o = Buf(2.6); for (int k = 0; k < 26; k++) { double d = U(.05, .2); double[] g = Buf(d); double f0 = U(120, 420), f1 = f0 * U(1.4, 3.2), ph = 0; for (int i = 0; i < g.Length; i++) { double u = i / (double)g.Length; ph += (f0 + (f1 - f0) * u) / SR; g[i] = Math.Sin(2 * Math.PI * ph) * Math.Sin(Math.PI * u) * .6; } Mix(o, g, U(0, 2.3), U(.3, .9)); } Mix(o, Fil(Graos(2.4, 420, 300, 1800, 1.2), LP, 1600, .8), .05, 1.0); return Rev(o, .5, .2, .6); }
  static double[] Talher() { double[] o = Buf(1.0); Mix(o, Reson(.6, new double[] { 2300, 3650, 5200, 7100 }, .08, .2), 0, .6); Mix(o, Reson(.5, new double[] { 2700, 4100, 6000 }, .06, .2), .22, .5); Mix(o, Reson(.3, new double[] { 900, 1500 }, .02, .4), .24, .5); return o; }
  static double[] Comer() { double[] o = Buf(1.1); for (int k = 0; k < 4; k++) Mix(o, Graos(.16, 60, 700, 3600, .05), k * .24, .9 - k * .12); return Fil(o, LP, 4200, .7); }
  static double[] Ziper() { double[] o = Buf(.9); double em = 0; while (em < .55) { double[] c = Fil(Branco(.006), BP, 2200 + em * 3000, 2); Mix(o, c, em, .9); em += .007 - em * .004; } Mix(o, Graos(.35, 60, 400, 2200, .12), .5, .5); return o; }
  static double[] Carrinho() { double[] o = Buf(4.0); double[] r = Fil(Marrom(4.0), LP, 500, .7); Mix(o, r, 0, .5); for (double t = 0; t < 3.7; t += U(.05, .22)) Mix(o, Reson(.2, new double[] { U(1500, 2600), U(3000, 4600) }, .02, .2), t, U(.05, .22)); return Env(o, .3, .6); }
  static double[] Moscas(double s) { double[] o = Buf(s); for (int k = 0; k < 4; k++) { double ph = 0, f = U(170, 235), fa = U(0, 6); for (int i = 0; i < o.Length; i++) { double t = i / (double)SR; ph += f * (1 + .05 * Math.Sin(t * 5 + fa)) / SR; o[i] += (2 * (ph - Math.Floor(ph)) - 1) * Math.Pow(.5 + .5 * Math.Sin(t * (1.3 + k * .4) + fa), 3) * .3; } } return Fil(o, BP, 900, .6); }
  static double[] Dia(double s) { double[] v = Fil(Vento(s), HP, 180, .7); double[] p = Fil(Rosa(s), BP, 2600, .6); double[] l = Lento(s + .1, .35); for (int i = 0; i < v.Length; i++) v[i] = v[i] * .8 + p[i] * .10 * l[i]; return v; }
  public static void Novos() {
    for (int k = 1; k <= 5; k++) Salva("p_neve" + k, PNeve(), null, .8);
    for (int k = 1; k <= 3; k++) Salva("corvo" + k, Corvo(), null, .8);
    { double[] a = Asas(5.0, 34), c = Buf(5.0); for (int k = 0; k < 9; k++) Mix(c, Corvo(), U(0, 3.2), U(.15, .5)); Mix(c, a, 0, 1.2); Salva("revoada", Rev(c, 1.4, .25, 1.4), null, .92); }
    Salva("cachorros", Caes(13), null, .8); Salva("grito_gente", GritoGente(), null, .95); Salva("tiro", Tiro(), null, .98); Sv("ferrolho", Ferrolho());
    Salva("sirene", Sirene(8.0), null, .7); Salva("motor", Loop(Motor(4.4), .4), null, .8); Sv("partida", Partida()); Sv("despeja", Despeja(2.6)); Sv("nojo", Nojo());
    Salva("talher", Talher(), null, .6); Sv("comer", Comer()); Salva("mochila", Ziper(), null, .7); Salva("carrinho", Carrinho(), null, .6); Salva("moscas", Loop(Moscas(4.3), .3), null, .5); Est("amb_dia", Dia, 12, 1.5, .7);
  }
  public static void VSeca(string f, string n, double tom) { Salva(n, Rev(Tom(Le(f), tom), .25, .10, .5), null, .92); }
"@
$cs = $cs.Substring(0, $cs.LastIndexOf('}')) + $novo + "`n}"
Add-Type -TypeDefinition $cs
[S]::Dir = $saida
if (-not $SoVozes) { [S]::Novos(); 'sons ok' }
if ($SoSons) { return }

# ---------------------------------------------------------------- vozes (OneCore)
Add-Type -AssemblyName System.Runtime.WindowsRuntime
[void][Windows.Media.SpeechSynthesis.SpeechSynthesizer, Windows.Media.SpeechSynthesis, ContentType = WindowsRuntime]
[void][Windows.Storage.Streams.DataReader, Windows.Storage.Streams, ContentType = WindowsRuntime]
$asTask = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object { $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' })[0]
function Espera($op, $tipo) { $t = $asTask.MakeGenericMethod($tipo).Invoke($null, @($op)); $t.Wait() | Out-Null; $t.Result }
$sint = New-Object Windows.Media.SpeechSynthesis.SpeechSynthesizer
$vozes = [Windows.Media.SpeechSynthesis.SpeechSynthesizer]::AllVoices
$tmp = Join-Path $env:TEMP ('vz_' + [guid]::NewGuid().ToString('N')); New-Item -ItemType Directory $tmp | Out-Null
function Fala($voz, $texto, $vel) {
  $sint.Voice = $vozes | Where-Object { $_.DisplayName -match $voz -and $_.Language -eq 'pt-BR' } | Select-Object -First 1
  $sint.Options.SpeakingRate = $vel
  $st = Espera ($sint.SynthesizeTextToStreamAsync($texto)) ([Windows.Media.SpeechSynthesis.SpeechSynthesisStream])
  $dr = New-Object Windows.Storage.Streams.DataReader ($st.GetInputStreamAt(0))
  [void](Espera ($dr.LoadAsync([uint32]$st.Size)) ([uint32]))
  $by = New-Object byte[] ([int]$st.Size); $dr.ReadBytes($by)
  $f = Join-Path $tmp ([guid]::NewGuid().ToString('N') + '.wav'); [IO.File]::WriteAllBytes($f, $by); return $f
}
$linhas = Get-Content (Join-Path $PSScriptRoot 'falas.txt') -Encoding UTF8 | Where-Object { $_ -and $_ -notmatch '^#' }
foreach ($l in $linhas) {
  $p = $l -split '\|'
  $id = $p[0].Trim(); $voz = $p[1].Trim(); $vel = [double]::Parse($p[2], [Globalization.CultureInfo]::InvariantCulture); $tom = [double]::Parse($p[3], [Globalization.CultureInfo]::InvariantCulture); $modo = $p[4].Trim(); $txt = $p[5].Trim()
  $f = Fala $voz $txt $vel
  switch ($modo) { 'seca' { [S]::VSeca($f, $id, $tom) } 'gente' { [S]::VGente($f, $id, $tom) } 'radio' { [S]::VRadio($f, $id, $tom, .5) } 'mimica' { [S]::VMimica($f, $id, $tom, 1.2, .55) } }
}
"falas: $($linhas.Count)"