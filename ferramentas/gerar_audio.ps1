# Sintetiza TODO o audio do jogo (nada e gravado nem baixado).
# As falas usam a voz do Windows (Microsoft Maria) processada: sao provisorias.
$raiz = Split-Path -Parent $PSScriptRoot
$saida = Join-Path $raiz 'jogo\som'
New-Item -ItemType Directory -Force $saida | Out-Null

Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Collections.Generic;

public static class S {
  public const int SR = 44100;
  public static string Dir;
  static Random R = new Random(1234);
  static double U(double a, double b) { return a + R.NextDouble() * (b - a); }
  static double N() { return R.NextDouble() * 2 - 1; }
  static double[] Buf(double s) { return new double[(int)(s * SR)]; }

  // ---------- filtros
  class Bq {
    double b0, b1, b2, a1, a2, x1, x2, y1, y2;
    public Bq(int tipo, double f, double q) { Set(tipo, f, q); }
    public void Set(int tipo, double f, double q) {
      f = Math.Max(15, Math.Min(SR * .47, f));
      double w = 2 * Math.PI * f / SR, c = Math.Cos(w), s = Math.Sin(w), al = s / (2 * q), a0 = 1 + al;
      if (tipo == 0) { b0 = (1 - c) / 2; b1 = 1 - c; b2 = b0; }
      else if (tipo == 1) { b0 = (1 + c) / 2; b1 = -(1 + c); b2 = b0; }
      else { b0 = al; b1 = 0; b2 = -al; }
      a1 = -2 * c; a2 = 1 - al;
      b0 /= a0; b1 /= a0; b2 /= a0; a1 /= a0; a2 /= a0;
    }
    public double P(double x) { double y = b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2; x2 = x1; x1 = x; y2 = y1; y1 = y; return y; }
  }
  const int LP = 0, HP = 1, BP = 2;
  static double[] Fil(double[] a, int t, double f, double q) { Bq b = new Bq(t, f, q); double[] o = new double[a.Length]; for (int i = 0; i < a.Length; i++) o[i] = b.P(a[i]); return o; }
  static double[] Branco(double s) { double[] a = Buf(s); for (int i = 0; i < a.Length; i++) a[i] = N(); return a; }
  static double[] Rosa(double s) {
    double[] a = Buf(s); double b0 = 0, b1 = 0, b2 = 0;
    for (int i = 0; i < a.Length; i++) { double w = N(); b0 = .99765 * b0 + w * .0990460; b1 = .96300 * b1 + w * .2965164; b2 = .57000 * b2 + w * 1.0526913; a[i] = (b0 + b1 + b2 + w * .1848) * .25; }
    return a;
  }
  static double[] Marrom(double s) { double[] a = Buf(s); double v = 0; for (int i = 0; i < a.Length; i++) { v = v * .996 + N() * .06; a[i] = v * 1.6; } return a; }
  // ruido lento 0..1
  static double[] Lento(double s, double hz) {
    double[] a = Buf(s); int p = Math.Max(1, (int)(SR / hz)); double x = R.NextDouble(), y = R.NextDouble();
    for (int i = 0; i < a.Length; i++) { int k = i % p; if (k == 0) { x = y; y = R.NextDouble(); } double t = k / (double)p; t = t * t * (3 - 2 * t); a[i] = x + (y - x) * t; }
    return a;
  }
  static void Mix(double[] d, double[] s, double em, double g) { int o = (int)(em * SR); for (int i = 0; i < s.Length && o + i < d.Length; i++) if (o + i >= 0) d[o + i] += s[i] * g; }
  static double Env(double t, double a, double d) { return t < a ? t / a : Math.Exp(-(t - a) / d); }
  static double[] Norm(double[] a, double p) { double m = 1e-9; foreach (double v in a) m = Math.Max(m, Math.Abs(v)); double[] o = new double[a.Length]; for (int i = 0; i < a.Length; i++) o[i] = a[i] / m * p; return o; }
  static double[] Sat(double[] a, double g) { double[] o = new double[a.Length]; for (int i = 0; i < a.Length; i++) o[i] = Math.Tanh(a[i] * g); return o; }
  static double[] Loop(double[] a, double xf) {
    int n = (int)(xf * SR), L = a.Length - n; double[] o = new double[L];
    for (int i = 0; i < L; i++) o[i] = a[i];
    for (int i = 0; i < n; i++) { double t = i / (double)n; o[i] = a[i] * Math.Sqrt(t) + a[L + i] * Math.Sqrt(1 - t); }
    return o;
  }
  static double[] Fade(double[] a, double fi, double fo) { int n = (int)(fi * SR), m = (int)(fo * SR); for (int i = 0; i < n && i < a.Length; i++) a[i] *= i / (double)n; for (int i = 0; i < m && i < a.Length; i++) a[a.Length - 1 - i] *= i / (double)m; return a; }
  static double[] Rev(double[] a, double cauda, double wet, double esc) {
    int n = a.Length + (int)(cauda * SR); double[] o = new double[n];
    int[] d = { (int)(1557 * esc), (int)(1617 * esc), (int)(1491 * esc), (int)(1422 * esc), (int)(1277 * esc), (int)(1356 * esc) };
    double[] w = new double[n];
    foreach (int dl in d) {
      double[] b = new double[dl]; int p = 0; double st = 0; double fb = Math.Pow(10, -3.0 * dl / SR / Math.Max(.2, cauda));
      for (int i = 0; i < n; i++) { double y = b[p]; st = y * .62 + st * .38; b[p] = (i < a.Length ? a[i] : 0) + st * fb; if (++p >= dl) p = 0; w[i] += y / d.Length; }
    }
    int[] ap = { 556, 441, 341 };
    foreach (int dl in ap) { double[] b = new double[dl]; int p = 0; for (int i = 0; i < n; i++) { double y = b[p] - .5 * w[i]; b[p] = w[i] + .5 * y; w[i] = y; if (++p >= dl) p = 0; } }
    for (int i = 0; i < n; i++) o[i] = (i < a.Length ? a[i] * (1 - wet * .5) : 0) + w[i] * wet * 2.2;
    return o;
  }
  static double[] Inv(double[] a) { double[] o = (double[])a.Clone(); Array.Reverse(o); return o; }
  static double[] Resamp(double[] a, double r) { int n = (int)(a.Length / r); double[] o = new double[n]; for (int i = 0; i < n; i++) { double p = i * r; int k = (int)p; double f = p - k; double x = k < a.Length ? a[k] : 0, y = k + 1 < a.Length ? a[k + 1] : 0; o[i] = x + (y - x) * f; } return o; }
  // estica no tempo (OLA com busca de similaridade)
  static double[] Estica(double[] a, double f) {
    int w = 2048, h = w / 4, n = (int)(a.Length * f) + w; double[] o = new double[n]; double[] g = new double[n];
    int pr = 0;
    for (int t = 0; t + w < n; t += h) {
      int ideal = (int)(t / f), best = ideal; double bs = double.MinValue;
      if (t > 0) for (int d = -400; d <= 400; d += 8) { int q = ideal + d; if (q < 0 || q + w >= a.Length || pr + h + 600 >= a.Length) continue; double s = 0; for (int i = 0; i < 600; i += 4) s += a[q + i] * a[pr + h + i]; if (s > bs) { bs = s; best = q; } }
      if (best + w >= a.Length) break; if (best < 0) best = 0; pr = best;
      for (int i = 0; i < w; i++) { double win = .5 - .5 * Math.Cos(2 * Math.PI * i / w); o[t + i] += a[best + i] * win; g[t + i] += win; }
    }
    for (int i = 0; i < n; i++) if (g[i] > .05) o[i] /= g[i];
    return o;
  }
  static double[] Tom(double[] a, double r) { return Resamp(Estica(a, r), r); }

  // ---------- arquivos
  static void Salva(string nome, double[] l, double[] r, double pico) {
    double m = 1e-9; foreach (double v in l) m = Math.Max(m, Math.Abs(v)); if (r != null) foreach (double v in r) m = Math.Max(m, Math.Abs(v));
    int ch = r == null ? 1 : 2, n = r == null ? l.Length : Math.Min(l.Length, r.Length);
    using (BinaryWriter b = new BinaryWriter(File.Create(Path.Combine(Dir, nome + ".wav")))) {
      b.Write(new char[] { 'R', 'I', 'F', 'F' }); b.Write(36 + n * ch * 2); b.Write(new char[] { 'W', 'A', 'V', 'E', 'f', 'm', 't', ' ' });
      b.Write(16); b.Write((short)1); b.Write((short)ch); b.Write(SR); b.Write(SR * ch * 2); b.Write((short)(ch * 2)); b.Write((short)16);
      b.Write(new char[] { 'd', 'a', 't', 'a' }); b.Write(n * ch * 2);
      for (int i = 0; i < n; i++) { b.Write((short)(l[i] / m * pico * 32700)); if (r != null) b.Write((short)(r[i] / m * pico * 32700)); }
    }
  }
  static void Sv(string n, double[] a) { Salva(n, a, null, .9); }
  public static double[] Le(string f) {
    byte[] d = File.ReadAllBytes(f); int p = 12, sr = 22050, ch = 1; double[] o = new double[0];
    while (p + 8 <= d.Length) {
      string id = System.Text.Encoding.ASCII.GetString(d, p, 4); int sz = BitConverter.ToInt32(d, p + 4); p += 8;
      if (id == "fmt ") { ch = BitConverter.ToInt16(d, p + 2); sr = BitConverter.ToInt32(d, p + 4); }
      if (id == "data") { sz = Math.Min(sz, d.Length - p); int n = sz / 2 / ch; o = new double[n]; for (int i = 0; i < n; i++) o[i] = BitConverter.ToInt16(d, p + i * 2 * ch) / 32768.0; }
      p += sz + (sz & 1);
    }
    // corta silencio
    int a = 0, z = o.Length - 1; while (a < z && Math.Abs(o[a]) < .012) a++; while (z > a && Math.Abs(o[z]) < .012) z--;
    a = Math.Max(0, a - 400); z = Math.Min(o.Length - 1, z + 1500);
    double[] c = new double[z - a + 1]; Array.Copy(o, a, c, 0, c.Length);
    return Norm(Resamp(c, sr / (double)SR), .9);
  }

  // ---------- AMBIENTES
  static double[] Vento(double s) {
    double[] p = Rosa(s), l1 = Lento(s, .25), l2 = Lento(s, .7), o = Buf(s); Bq a = new Bq(BP, 300, .6), b = new Bq(BP, 700, 2.5), c = new Bq(HP, 2600, .7);
    for (int i = 0; i < o.Length; i++) {
      double g = l1[i] * .7 + l2[i] * .3;
      if (i % 64 == 0) { a.Set(BP, 180 + 320 * g, .55); b.Set(BP, 420 + 520 * g, 3.5); }
      o[i] = a.P(p[i]) * (.25 + g) + b.P(p[i]) * g * g * .9 + c.P(p[i]) * g * g * g * .5;
    }
    return o;
  }
  static double[] Insetos(double s) {
    double[] o = Buf(s);
    for (int k = 0; k < 9; k++) {
      double f = U(3600, 5200), per = U(.55, 1.1), amp = U(.1, .5), fase = U(0, 1); int pul = 2 + R.Next(4);
      for (double t = fase; t < s; t += per * U(.96, 1.04)) {
        for (int q = 0; q < pul; q++) { int st = (int)((t + q * .035) * SR), n = (int)(.026 * SR); for (int i = 0; i < n && st + i < o.Length; i++) { double e = Math.Sin(Math.PI * i / n); o[st + i] += Math.Sin(2 * Math.PI * f * i / SR) * e * e * amp * .5; } }
      }
    }
    double[] h = Fil(Fil(Branco(s), BP, 6200, 6), BP, 6200, 3); double[] lo = Lento(s, .4);
    for (int i = 0; i < o.Length; i++) { double t = i / (double)SR; o[i] += h[i] * (.5 + .5 * Math.Sign(Math.Sin(2 * Math.PI * 27 * t))) * .35 * lo[i]; }
    return o;
  }
  static double[] Riacho(double s) {
    double[] o = Buf(s), n = Rosa(s), l = Lento(s, 3); Bq a = new Bq(BP, 520, .7), b = new Bq(BP, 1700, .8);
    for (int i = 0; i < o.Length; i++) o[i] = a.P(n[i]) * (.35 + .25 * l[i]) + b.P(n[i]) * .16;
    int tot = (int)(s * 70);
    for (int k = 0; k < tot; k++) { double f = U(350, 1500), d = U(.012, .05), g = U(.01, .10); int st = (int)(U(0, s) * SR), len = (int)(d * 5 * SR); double ph = 0; for (int i = 0; i < len && st + i < o.Length; i++) { double t = i / (double)SR; ph += 2 * Math.PI * f * (1 + t * 9) / SR; o[st + i] += Math.Sin(ph) * Math.Exp(-t / d) * g; } }
    return o;
  }
  static double[] Drone(double s, double sem) {
    double[] o = Buf(s); double[] fs = { 32.7, 36.71, 49.0, 51.9, 65.4, 69.3 };
    for (int k = 0; k < fs.Length; k++) { double[] l = Lento(s, .12); double f = fs[k] * (1 + sem * .004), ph = U(0, 6); for (int i = 0; i < o.Length; i++) { double t = i / (double)SR; o[i] += (Math.Sin(2 * Math.PI * f * t + ph + Math.Sin(t * .7) * .6) + .35 * Math.Sin(4.02 * Math.PI * f * t)) * l[i] * .22; } }
    double[] m = Fil(Marrom(s), LP, 160, .8); double[] g = Fil(Fil(Branco(s), BP, 940, 25), BP, 940, 25), l2 = Lento(s, .2);
    for (int i = 0; i < o.Length; i++) o[i] += m[i] * .3 + g[i] * l2[i] * l2[i] * 1.2;
    return o;
  }
  static double[] Cordas(double s, double[] fs, double trem) {
    double[] o = Buf(s);
    foreach (double f0 in fs) for (int v = 0; v < 3; v++) {
      double f = f0 * (1 + U(-.006, .006)), ph = R.NextDouble(); double[] l = Lento(s, .5);
      Bq lp = new Bq(LP, Math.Min(9000, f * 5), .8);
      for (int i = 0; i < o.Length; i++) { double t = i / (double)SR; ph += f * (1 + .004 * Math.Sin(2 * Math.PI * 5.3 * t + v)) / SR; if (ph > 1) ph -= 1; double tr = trem > 0 ? (.55 + .45 * Math.Sin(2 * Math.PI * trem * t + v * 1.3)) : 1; o[i] += lp.P(ph * 2 - 1) * (.3 + l[i]) * tr * .16; }
    }
    return o;
  }
  static double[] Batida(double f, double d) { double[] o = Buf(d * 6); double ph = 0; for (int i = 0; i < o.Length; i++) { double t = i / (double)SR; ph += 2 * Math.PI * (f + f * 2.2 * Math.Exp(-t * 28)) / SR; o[i] = Math.Sin(ph) * Env(t, .003, d) + N() * Math.Exp(-t * 90) * .3; } return o; }

  // ---------- CRIATURA
  static double[] Grito(double s, double f0, double rasp) {
    double[] o = Buf(s); double ph = 0; double[] l = Lento(s, 9); Bq a = new Bq(BP, 1100, 3), b = new Bq(BP, 2300, 4), c = new Bq(BP, 3700, 5);
    for (int i = 0; i < o.Length; i++) {
      double t = i / (double)SR, u = t / s; double f = f0 * (1 + .75 * Math.Sin(Math.PI * Math.Pow(u, .55)) - .45 * u) * (1 + (l[i] - .5) * .22);
      ph += f / SR; double src = 2 * (ph - Math.Floor(ph)) - 1; double am = 1 - rasp * (.5 + .5 * Math.Sign(Math.Sin(2 * Math.PI * (54 + 26 * l[i]) * t)));
      double x = src * am + N() * (.35 + rasp * .5);
      double e = Math.Min(1, t / .06) * Math.Min(1, (s - t) / (s * .35));
      o[i] = (a.P(x) * 1.5 + b.P(x) * 1.2 + c.P(x) * .9 + x * .06) * e;
    }
    return Sat(Norm(o, 1), 2.2);
  }
  static double[] Rosna(double s) {
    double[] o = Buf(s); double ph = 0; double[] l = Lento(s, 5); Bq a = new Bq(BP, 190, 4), b = new Bq(BP, 520, 5), c = new Bq(BP, 1250, 6);
    for (int i = 0; i < o.Length; i++) { double t = i / (double)SR; ph += (17 + 12 * l[i]) / SR; double src = 0; if (ph >= 1) { ph -= 1; src = 22 * U(.5, 1); } src += N() * .12; double e = Math.Sin(Math.PI * t / s); o[i] = (a.P(src) * 1.4 + b.P(src) + c.P(src) * .6) * e; }
    return Sat(Norm(o, 1), 1.8);
  }
  static double[] Estalos(double s, int n) {
    double[] o = Buf(s); for (int k = 0; k < n; k++) { double em = U(0, s * .8); double f = U(700, 2600); double[] g = Buf(.06); Bq b = new Bq(BP, f, 5); for (int i = 0; i < g.Length; i++) g[i] = b.P((i < 40 ? N() * 6 : 0) + N() * .02) * Math.Exp(-i / (double)SR * 70); Mix(o, Norm(g, 1), em, U(.3, 1)); }
    return o;
  }
  static double[] Assobio() {
    double[] o = Buf(3.2); double[,] nt = { { .05, .55, 1050, 1180 }, { .7, .45, 1390, 1400 }, { 1.25, 1.5, 1180, 880 } }; Bq b = new Bq(BP, 1200, 2);
    for (int k = 0; k < 3; k++) { double ph = 0; int n = (int)(nt[k, 1] * SR), st = (int)(nt[k, 0] * SR); for (int i = 0; i < n; i++) { double u = i / (double)n, t = i / (double)SR; double f = nt[k, 2] + (nt[k, 3] - nt[k, 2]) * u + Math.Sin(2 * Math.PI * 5.5 * t) * 12 * u; ph += 2 * Math.PI * f / SR; double e = Math.Min(1, t / .05) * Math.Min(1, (1 - u) * 5); o[st + i] += (Math.Sin(ph) + .06 * Math.Sin(2 * ph) + b.P(N()) * .16) * e; } }
    return Rev(o, 3.0, .75, 1.6);
  }
  static double[] Respira(double s, double tom, double dur) {
    double[] o = Buf(s); Bq a = new Bq(BP, tom, 1.2), b = new Bq(BP, tom * 2.6, 2);
    for (double t0 = 0; t0 + dur <= s + .001; t0 += dur) { int st = (int)(t0 * SR), n = (int)(dur * SR); for (int i = 0; i < n && st + i < o.Length; i++) { double u = i / (double)n; double e, f; if (u < .42) { e = Math.Sin(Math.PI * u / .42) * .75; f = 1.25; } else if (u < .92) { e = Math.Sin(Math.PI * (u - .42) / .5); f = .85; } else { e = 0; f = 1; } if (i % 64 == 0) { a.Set(BP, tom * f, 1.2); b.Set(BP, tom * 2.6 * f, 2); } double x = N(); o[st + i] += (a.P(x) + b.P(x) * .5) * e * e; } }
    return o;
  }

  // ---------- PASSOS E FOLEY
  static double[] Graos(double s, int n, double f1, double f2, double dec) {
    double[] o = Buf(s); for (int k = 0; k < n; k++) { double em = Math.Pow(R.NextDouble(), 1.6) * s * .7; double f = U(f1, f2); int len = (int)(U(.003, .02) * SR), st = (int)(em * SR); Bq b = new Bq(BP, f, 2); double g = U(.2, 1) * Math.Exp(-em / dec); for (int i = 0; i < len && st + i < o.Length; i++) o[st + i] += b.P(N()) * g * Math.Exp(-i / (double)len * 4); }
    return o;
  }
  static double[] PFolha() { double[] o = Graos(.34, 100, 1300, 6800, .10); Mix(o, Batida(62, .03), 0, .5); Mix(o, Graos(.2, 40, 800, 3000, .08), .07, .7); return o; }
  static double[] Reson(double s, double[] fs, double d, double ex) { double[] o = Buf(s); foreach (double f in fs) { double ph = U(0, 6), dd = d * U(.6, 1.2), g = U(.4, 1); for (int i = 0; i < o.Length; i++) { double t = i / (double)SR; o[i] += Math.Sin(2 * Math.PI * f * t + ph) * Math.Exp(-t / dd) * g; } } for (int i = 0; i < o.Length; i++) { double t = i / (double)SR; o[i] = o[i] / fs.Length + N() * Math.Exp(-t * 120) * ex; } return Fade(o, .001, .02); }
  static double[] PMadeira() { return Reson(.35, new double[] { U(88, 110), U(170, 210), U(290, 340), U(480, 560) }, .05, .35); }
  static double[] PMetal() { return Reson(.6, new double[] { U(170, 200), U(410, 460), U(760, 830), U(1380, 1500), U(2300, 2500) }, .12, .4); }
  static double[] PAgua() { double[] o = Buf(.6); Bq b = new Bq(BP, 900, .8); for (int i = 0; i < o.Length; i++) { double t = i / (double)SR; if (i % 64 == 0) b.Set(BP, 2600 * Math.Exp(-t * 5) + 350, .8); o[i] = b.P(N()) * Env(t, .015, .12); } for (int k = 0; k < 14; k++) { double f = U(400, 1200), d = U(.015, .04); double[] g = Buf(d * 5); double ph = 0; for (int i = 0; i < g.Length; i++) { double t = i / (double)SR; ph += 2 * Math.PI * f * (1 + t * 10) / SR; g[i] = Math.Sin(ph) * Math.Exp(-t / d); } Mix(o, g, U(.03, .4), U(.05, .2)); } return Fade(o, .001, .1); }
  static double[] PAsfalto() { double[] o = Graos(.16, 30, 900, 3600, .04); Mix(o, Batida(80, .02), 0, .9); return o; }
  static double[] Galho(double g) { double[] o = Buf(.7); for (int k = 0; k < 5; k++) { double em = k == 0 ? 0 : U(.01, .22); double[] c = Buf(.12); Bq b = new Bq(HP, U(500, 1500), .8); for (int i = 0; i < c.Length; i++) c[i] = b.P(N()) * Math.Exp(-i / (double)SR * U(60, 110)); Mix(o, c, em, k == 0 ? 1 : U(.15, .5)); } Mix(o, Batida(130, .03), 0, g); return Rev(o, 1.2, .35, 1.3); }
  static double[] Range(double s, double f, double q) {
    double[] o = Buf(s); double[] l = Lento(s, 6), l2 = Lento(s, 2); double ph = 0; Bq a = new Bq(BP, f * 6, q), b = new Bq(BP, f * 13, q);
    for (int i = 0; i < o.Length; i++) { ph += f * (.4 + 1.5 * l[i]) / SR; double x = 0; if (ph > 1) { ph -= 1; x = 10 * U(.4, 1); } x += N() * .05; o[i] = (a.P(x) + b.P(x) * .7) * l2[i]; }
    return Fade(o, .05, .2);
  }

  // ---------- AVIAO
  static double[] Cabine(double s, double rug) {
    double[] o = Buf(s), m = Fil(Marrom(s), LP, 420, .7), h = Fil(Branco(s), BP, 1500, .4), l = Lento(s, 1.2);
    for (int i = 0; i < o.Length; i++) { double t = i / (double)SR, v = 0; for (int k = 1; k <= 7; k++) v += (Math.Sin(2 * Math.PI * 86.0 * k * t) + Math.Sin(2 * Math.PI * 86.8 * k * t + k)) / (k * 1.25); o[i] = v * .16 + m[i] * 1.0 + h[i] * .07 + (rug > 0 ? N() * .03 * rug * l[i] : 0); }
    return o;
  }
  static double[] Pane(double s) {
    double[] o = Buf(s), m = Fil(Marrom(s), LP, 600, .7), l = Lento(s, 7), l2 = Lento(s, 1.5); double ph = 0;
    for (int i = 0; i < o.Length; i++) { double t = i / (double)SR; double f = 60 + 26 * l2[i]; ph += f / SR; double gate = l[i] > .42 ? 1 : .15; double x = (ph - Math.Floor(ph)) * 2 - 1; o[i] = x * gate * .5 + m[i] * 1.4; }
    for (int k = 0; k < (int)(s * 22); k++) Mix(o, Reson(.09, new double[] { U(300, 500), U(900, 1400), U(2100, 3300) }, .02, .5), U(0, s - .1), U(.05, .28));
    return o;
  }
  static double[] Queda(double s) {
    double[] o = Buf(s), n = Rosa(s), l = Lento(s, 4); Bq a = new Bq(BP, 300, 1), b = new Bq(BP, 900, 7); double ph = 0;
    for (int i = 0; i < o.Length; i++) { double t = i / (double)SR, u = t / s; if (i % 64 == 0) { a.Set(BP, 250 + 900 * u, .7); b.Set(BP, 500 + 1500 * u + 160 * l[i], 9); } ph += (320 + 900 * u * u + 40 * l[i]) / SR; double w = (ph - Math.Floor(ph)) * 2 - 1; o[i] = (a.P(n[i]) * 2.4 + b.P(n[i]) * 3.2 + b.P(w) * .14) * (.25 + .9 * u); }
    for (int k = 0; k < (int)(s * 16); k++) Mix(o, Reson(.12, new double[] { U(160, 400), U(700, 1200), U(1900, 3000) }, .03, .6), Math.Sqrt(R.NextDouble()) * (s - .2), U(.1, .4));
    return Fade(o, .4, .05);
  }
  static double[] Explosao(double s) { double[] o = Buf(s); Bq a = new Bq(LP, 900, .7); for (int i = 0; i < o.Length; i++) { double t = i / (double)SR; if (i % 64 == 0) a.Set(LP, 120 + 2600 * Math.Exp(-t * 3.2), .7); o[i] = a.P(N()) * Env(t, .004, s * .22) * 2; } Mix(o, Batida(38, .35), 0, 1.4); return Sat(o, 1.7); }
  static double[] Impacto() {
    double[] o = Buf(7.5); for (int k = 0; k < 16; k++) Mix(o, Galho(.9), U(0, 1.5), U(.3, .9));
    Mix(o, Explosao(4), 1.3, 1.4); Mix(o, Explosao(3), 1.9, 1.0); Mix(o, Explosao(2.5), 2.9, .7);
    for (int k = 0; k < 40; k++) Mix(o, Reson(1.1, new double[] { U(90, 240), U(300, 700), U(900, 1600), U(2000, 4200) }, U(.08, .3), .5), 1.2 + Math.Pow(R.NextDouble(), 1.5) * 4, U(.1, .5));
    Mix(o, Range(3, 70, 8), 2.0, .5); Mix(o, Range(2, 130, 8), 3.4, .4);
    return Fade(Sat(Norm(o, 1), 2.6), .01, 1.5);
  }

  static void Est(string n, Func<double, double[]> f, double s, double xf, double p) { Salva(n, Loop(f(s + xf), xf), Loop(f(s + xf), xf), p); }

  public static void Tudo() {
    Est("amb_vento", Vento, 24, 3, .8); Est("amb_insetos", Insetos, 14, 1.5, .7); Est("amb_drone", delegate(double s) { return Drone(s, N()); }, 26, 4, .8);
    Sv("amb_riacho", Loop(Riacho(13), 1.5));
    Est("mus_tensao", delegate(double s) { return Cordas(s, new double[] { 110, 116.5, 123.5, 233, 246.9 }, 0); }, 18, 3, .7);
    for (int v = 0; v < 1; v++) {
      double bt = 60.0 / 148, s = bt * 16; double[] l = Cordas(s + .5, new double[] { 73.4, 77.8, 311, 329.6 }, 9), r = Cordas(s + .5, new double[] { 73.4, 77.8, 155.6, 466 }, 9.3);
      double[] d = Buf(s + .5); int[] pat = { 0, 3, 4, 6, 8, 11, 12, 13, 14 }; foreach (int b in pat) { Mix(d, Batida(48, .16), b * bt, 1); } for (int b = 0; b < 32; b++) if (R.NextDouble() < .55) Mix(d, Batida(95, .05), b * bt / 2, .35);
      for (int k = 0; k < 7; k++) Mix(d, Norm(Range(.8, U(140, 320), 14), 1), U(0, s - .9), .3);
      for (int i = 0; i < l.Length; i++) { l[i] = Math.Tanh((l[i] * .9 + d[i] * .7) * 1.4); r[i] = Math.Tanh((r[i] * .9 + d[i] * .7) * 1.4); }
      Salva("mus_caca", Loop(l, .5), Loop(r, .5), .85);
    }
    { double[] a = Buf(4.5); Mix(a, Explosao(2.5), 0, .9); Mix(a, Fade(Cordas(3, new double[] { 932, 988, 1046, 1108, 1397, 1480 }, 13), .002, 2.2), 0, 1.6); Mix(a, Grito(1.1, 620, .7), .02, .35); Sv("stinger1", Rev(Sat(a, 1.5), 3, .5, 1.5)); }
    { double[] a = Buf(4); Mix(a, Batida(34, .6), 0, 1.3); Mix(a, Fade(Cordas(3.2, new double[] { 65, 69, 207, 220, 415 }, 0), .01, 2.5), 0, 1.3); Sv("stinger2", Rev(a, 3.5, .5, 1.6)); }
    { double[] a = Fade(Cordas(3.0, new double[] { 1864, 1975, 2093, 2217 }, 11), 2.6, .05); double[] o = Buf(3.2); Mix(o, a, 0, 1); Sv("stinger3", Rev(o, 2, .5, 1.4)); }
    // fauna
    { double[] o = Buf(5.2); double[] tm = { 0, .32, .68, .9, 1.9, 2.2, 2.56, 2.8 }; for (int k = 0; k < 8; k++) { double len = k == 7 ? 1.0 : .2; double f0 = k == 7 ? 520 : 470; double ph = 0; int st = (int)(tm[k] * SR), n = (int)(len * SR); Bq bb = new Bq(BP, 480, 2); for (int i = 0; i < n; i++) { double u = i / (double)n; double f = f0 * (1 + .12 * Math.Sin(Math.PI * u) - (k == 7 ? .34 * u : .05 * u)); ph += 2 * Math.PI * f / SR; double e = Math.Sin(Math.PI * Math.Pow(u, .7)); o[st + i] += (Math.Sin(ph) + .22 * Math.Sin(2 * ph) + .07 * Math.Sin(3 * ph) + bb.P(N()) * .25) * e; } } Sv("coruja", Rev(o, 3, .65, 1.7)); }
    { double[] o = Buf(2.6); double ph = 0; for (int i = 0; i < o.Length; i++) { double t = i / (double)SR, u = t / 2.2; if (u > 1) break; double f = 900 - 420 * u; ph += 2 * Math.PI * f / SR; double tr = .5 + .5 * Math.Sin(2 * Math.PI * 14 * t); o[i] = (Math.Sin(ph) + .15 * Math.Sin(2 * ph)) * tr * Math.Sin(Math.PI * u); } Sv("coruja2", Rev(o, 3, .65, 1.7)); }
    Sv("raposa", Rev(Grito(1.0, 640, .35), 3, .7, 1.7));
    // criatura
    Sv("cr_grito1", Rev(Grito(2.1, 430, .6), 2.8, .45, 1.6)); Sv("cr_grito2", Rev(Grito(1.4, 560, .8), 2.4, .45, 1.6));
    { double[] a = Grito(1.5, 300, .9); Mix(a, Grito(1.5, 780, .5), 0, .5); Mix(a, Rosna(1.5), 0, .9); Sv("cr_ataque", Rev(Sat(a, 1.6), 1.2, .3, 1.2)); }
    Sv("cr_rosna1", Rev(Rosna(2.2), 1.2, .3, 1.3)); Sv("cr_rosna2", Rev(Rosna(1.3), 1.2, .3, 1.3)); Sv("cr_estalos", Rev(Estalos(1.6, 12), 1.2, .35, 1.3)); Sv("cr_respira", Fade(Respira(3.2, 300, 1.6), .05, .2));
    for (int k = 1; k <= 3; k++) { double[] o = Buf(.5); Mix(o, Batida(44, .07), 0, 1); Mix(o, PFolha(), .01, .55); Sv("cr_passo" + k, Rev(o, .7, .2, 1.2)); }
    Sv("assobio", Assobio());
    // passos
    for (int k = 1; k <= 5; k++) { Sv("p_folha" + k, PFolha()); Sv("p_madeira" + k, PMadeira()); Sv("p_metal" + k, PMetal()); Sv("p_agua" + k, PAgua()); Sv("p_asfalto" + k, PAsfalto()); }
    for (int k = 1; k <= 4; k++) Sv("galho" + k, Galho(.2 + .15 * k));
    { double[] o = Graos(.9, 160, 1800, 7200, .6); Sv("arbusto", Fade(o, .05, .3)); }
    // corpo
    { double[] o = Buf(1.0); Mix(o, Fil(Batida(42, .06), LP, 160, .7), .0, 1); Mix(o, Fil(Batida(52, .04), LP, 190, .7), .26, .7); Sv("coracao", o); }
    Sv("resp_cansada", Loop(Respira(5.3, 620, 1.3), .1)); Sv("resp_medo", Loop(Respira(4.1, 520, .8), .1));
    { double[] o = Buf(9); for (int i = 0; i < o.Length; i++) { double t = i / (double)SR; o[i] = (Math.Sin(2 * Math.PI * 4300 * t) + .4 * Math.Sin(2 * Math.PI * 5170 * t)) * Math.Min(1, t / .02) * Math.Exp(-t / 2.6); } Sv("zumbido", o); }
    { double[] o = Buf(.5); Mix(o, Batida(70, .05), 0, 1); Mix(o, PFolha(), .02, .4); Sv("queda_corpo", o); }
    // aviao
    Est("av_cabine", delegate(double s) { return Cabine(s, 0); }, 10, 1.5, .75); Est("av_pane", Pane, 6, .8, .85); Sv("av_queda", Queda(16)); Sv("av_impacto", Impacto()); Sv("explosao", Rev(Explosao(3.5), 2.5, .35, 1.5));
    { double[] o = Buf(1.4); for (int k = 0; k < 2; k++) { double ph = 0; int st = (int)(k * .7 * SR), n = (int)(.5 * SR); for (int i = 0; i < n; i++) { double u = i / (double)n; ph += (420 + 520 * u) / SR; double x = (ph - Math.Floor(ph)) < .5 ? 1 : -1; o[st + i] = x * Math.Min(1, u * 30) * Math.Min(1, (1 - u) * 20); } } Sv("av_alarme", Fil(o, LP, 3800, .7)); }
    { double[] o = Buf(2.2); double[] f = { 660, 523 }; for (int k = 0; k < 2; k++) Mix(o, Reson(1.6, new double[] { f[k], f[k] * 2.001 }, .4, 0), k * .42, 1); Sv("av_chime", o); }
    Sv("metal1", Rev(Range(2.6, 48, 9), 1.6, .4, 1.4)); Sv("metal2", Rev(Range(1.8, 85, 11), 1.6, .4, 1.4)); Sv("batida_metal", Rev(Reson(1.2, new double[] { 110, 262, 431, 877, 1730 }, .2, .6), 1, .3, 1.2));
    // fogo, radio, objetos
    { double[] o = Fil(Marrom(9), LP, 500, .7), l = Lento(9, 5); for (int i = 0; i < o.Length; i++) o[i] *= .5 + .5 * l[i]; for (int k = 0; k < 320; k++) Mix(o, Graos(.03, 3, 1200, 6000, .01), U(0, 8.9), U(.3, 1.6)); Sv("fogo", Loop(o, 1)); }
    { double[] o = Fil(Branco(5), BP, 1900, .5), l = Lento(5, 12); for (int i = 0; i < o.Length; i++) o[i] *= .35 + .65 * l[i] * l[i]; for (int k = 0; k < 8; k++) { double f = U(500, 2600); double[] g = Buf(.4); for (int i = 0; i < g.Length; i++) g[i] = Math.Sin(2 * Math.PI * (f + 500 * i / g.Length) * i / SR) * Math.Sin(Math.PI * i / g.Length); Mix(o, g, U(0, 4.5), .07); } Sv("radio_estatica", Loop(o, .5)); }
    { double[] o = Buf(.25); for (int i = 0; i < o.Length; i++) { double t = i / (double)SR; o[i] = (N() * Math.Exp(-t * 160)) + .5 * Math.Sin(2 * Math.PI * 1150 * t) * (t > .05 && t < .17 ? 1 : 0); } Sv("radio_clique", o); }
    Sv("papel", Fade(Graos(.6, 120, 2600, 9000, .5), .02, .15)); { double[] o = Graos(.25, 30, 700, 2500, .1); Mix(o, Batida(120, .02), 0, .5); Sv("pegar", o); }
    { double[] o = Range(1.5, 30, 16); Mix(o, Reson(.4, new double[] { 120, 260, 510 }, .05, .4), 1.1, .5); Sv("porta", Rev(o, .8, .25, 1)); } Sv("madeira_range1", Rev(Range(1.3, 22, 18), .6, .25, 1)); Sv("madeira_range2", Rev(Range(.9, 38, 14), .6, .25, 1));
    { double[] o = Buf(.5); Mix(o, Reson(.15, new double[] { 1900, 3100, 4700 }, .02, .5), 0, .7); Mix(o, Reson(.2, new double[] { 900, 2100, 3900 }, .03, .5), .18, 1); Sv("chave", o); }
    Sv("pedra", Reson(.16, new double[] { 1400, 2500, 3900 }, .02, .9)); { double[] o = Graos(1.4, 90, 900, 4000, .25); Sv("fosforo", Fade(Fil(o, HP, 1500, .7), .01, .5)); }
    // caminhao e cidade
    { double s = 5; double[] o = Buf(s), m = Fil(Marrom(s), LP, 260, .7); double ph = 0; double[] l = Lento(s, 3); for (int i = 0; i < o.Length; i++) { ph += (27 + 2 * l[i]) / SR; double x = ph - Math.Floor(ph); o[i] = Math.Exp(-x * 5) * .8 + m[i] * .9 + (x < .1 ? N() * .25 : 0); } Sv("caminhao", Loop(Fil(o, LP, 900, .7), .5)); }
    { double[] o = Cordas(1.1, new double[] { 311, 370 }, 0); Sv("buzina", Fade(Sat(o, 2), .02, .15)); } { double[] o = Buf(4); for (int i = 0; i < o.Length; i++) { double t = i / (double)SR; o[i] = Math.Sin(2 * Math.PI * 120 * t) + .5 * Math.Sin(2 * Math.PI * 240 * t) + .3 * Math.Sin(2 * Math.PI * 360 * t) + N() * .05; } Sv("neon", Loop(o, .1)); }
    { double[] o = Buf(2.5); for (int k = 0; k < 14; k++) Mix(o, Batida(U(50, 70), .1), k * .12, .3); Sv("sub", Rev(Batida(30, .9), 1.5, .3, 1.5)); }
  }

  // ---------- VOZES
  static double[] Sussurro(double[] a) {
    int B = 26; double[] o = new double[a.Length];
    for (int b = 0; b < B; b++) {
      double f = 180 * Math.Pow(2, b * 5.4 / B); Bq x = new Bq(BP, f, 5), y = new Bq(BP, f, 5); double e = 0, k = 1 - Math.Exp(-1.0 / (.008 * SR));
      double hi = f > 1500 ? 1.8 : (f < 500 ? .5 : 1);
      for (int i = 0; i < a.Length; i++) { double v = Math.Abs(x.P(a[i])); e += (v - e) * k; o[i] += y.P(N()) * e * hi; }
    }
    return Norm(o, 1);
  }
  static double[] Radio(double[] a, double ru) { double[] o = Fil(Fil(a, HP, 420, .8), LP, 2900, .9); o = Sat(Norm(o, 1), 2.4); double[] l = Lento(o.Length / (double)SR + .1, 6); for (int i = 0; i < o.Length; i++) o[i] = o[i] * (1 - ru * .5 * l[i]) + N() * .05 * (1 + ru * 4 * l[i] * l[i]); return Fil(o, LP, 3200, .7); }
  static double[] Pad(double[] a, double ini, double fim) { double[] o = new double[a.Length + (int)((ini + fim) * SR)]; Array.Copy(a, 0, o, (int)(ini * SR), a.Length); return o; }
  public static void VPiloto(string f, string n, double ru) { double[] a = Radio(Pad(Le(f), .12, .2), ru); Mix(a, Reson(.08, new double[] { 1500, 2600 }, .01, .8), 0, .25); Salva(n, a, null, .85); }
  public static void VGente(string f, string n, double tom) { Salva(n, Rev(Tom(Le(f), tom), .6, .25, .8), null, .9); }
  public static void VRadio(string f, string n, double tom, double ru) { double[] a = Radio(Pad(Tom(Le(f), tom), .15, .3), ru); Salva(n, a, null, .88); }
  // mimica: voz humana quase certa, com subtom grave, eco reverso
  public static void VMimica(string f, string n, double tom, double len, double estranho) {
    double[] v = Estica(Le(f), len); double[] a = Tom(v, tom); double[] g = Tom(v, tom * .52); double[] w = Sussurro(a);
    int L = Math.Max(a.Length, g.Length); double[] m = new double[L];
    for (int i = 0; i < L; i++) { double t = i / (double)SR; double tre = 1 - estranho * .35 * (.5 + .5 * Math.Sin(2 * Math.PI * 31 * t)); m[i] = ((i < a.Length ? a[i] * .85 : 0) * tre + (i < g.Length ? g[i] * .5 * estranho : 0) + (i < w.Length ? w[i] * .35 : 0)); }
    double[] pre = Inv(Rev(Inv(m), 1.3, .5, 1.4)); double[] o = Rev(pre, 3.2, .6, 1.7);
    Salva(n, Fade(o, .05, .3), null, .9);
  }
  public static void VSussurro(string f, string n, double len) { double[] w = Sussurro(Estica(Le(f), len)); double[] pre = Inv(Rev(Inv(w), .8, .35, 1.2)); Salva(n, Rev(pre, 1.6, .4, 1.3), null, .85); }
  public static void VCoro(string[] fs, string n) {
    double s = 15; double[] l = Buf(s), r = Buf(s); foreach (string f in fs) { double[] w = Sussurro(Le(f)); for (int k = 0; k < 3; k++) { double em = U(0, s - 1); Mix(l, w, em, U(.1, .7)); Mix(r, w, em + U(-.02, .02), U(.1, .7)); if (R.NextDouble() < .5) Mix(l, Inv(w), U(0, s - 1), .4); else Mix(r, Inv(w), U(0, s - 1), .4); } }
    Salva(n, Loop(l, 2), Loop(r, 2), .8);
  }
}
'@

[S]::Dir = $saida
[S]::Tudo()
"efeitos prontos"

# ------------------------------------------------------------------ vozes
Add-Type -AssemblyName System.Speech
$tmp = Join-Path $env:TEMP ('vozes_' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory $tmp | Out-Null
$sint = New-Object System.Speech.Synthesis.SpeechSynthesizer
$v = $sint.GetInstalledVoices() | Where-Object { $_.VoiceInfo.Culture.Name -eq 'pt-BR' } | Select-Object -First 1
if ($v) { $sint.SelectVoice($v.VoiceInfo.Name) }
function Fala($id, $texto, $vel = 0) { $f = Join-Path $tmp "$id.wav"; $sint.Rate = $vel; $sint.SetOutputToWaveFile($f); $sint.Speak($texto); $sint.SetOutputToNull(); return $f }

# este arquivo e salvo em ASCII: acentos via codigo
$a1=[char]0xE1; $e1=[char]0xE9; $i1=[char]0xED; $o1=[char]0xF3; $u1=[char]0xFA; $at=[char]0xE3; $ot=[char]0xF5; $ac=[char]0xE2; $ec=[char]0xEA; $cc=[char]0xE7; $ag=[char]0xE0; $oc=[char]0xF4

[S]::VPiloto((Fala 'p1' "Boa noite, senhores passageiros. Aqui ${e1} a comandante. Estamos sobrevoando os montes Apalaches. Lua cheia do lado direito da aeronave. Pouso previsto em quarenta minutos." 0), 'v_piloto1', .2)
[S]::VPiloto((Fala 'p2' "Senhores, apertem os cintos. Vamos atravessar uma ${a1}rea de turbul${ec}ncia." 0), 'v_piloto2', .3)
[S]::VPiloto((Fala 'p3' "Torre, perdemos o motor direito. Repito, perdemos o motor direito. Tem alguma coisa aqui fora. Tem uma luz aqui fora." 2), 'v_piloto3', .7)
[S]::VPiloto((Fala 'p4' "Posi${cc}${at}o de impacto! Posi${cc}${at}o de impacto!" 3), 'v_piloto4', 1.0)
[S]::VGente((Fala 'c1' "Abaixem a cabe${cc}a! Abaixem a cabe${cc}a!" 3), 'v_comissaria', 1.12)
[S]::VMimica((Fala 'm1' "Alex." -4), 'v_alex1', .86, 1.35, .5)
[S]::VMimica((Fala 'm2' "Alex? Cad${ec} voc${ec}?" -2), 'v_alex2', .9, 1.15, .45)
[S]::VMimica((Fala 'm3' "Socorro. Me ajuda. Por aqui." -2), 'v_socorro', .92, 1.15, .5)
[S]::VMimica((Fala 'm4' "Apertem os cintos." -3), 'v_cintos', .78, 1.3, 1.0)
[S]::VMimica((Fala 'm5' "Posi${cc}${at}o de impacto." -4), 'v_impacto', .72, 1.4, 1.0)
[S]::VMimica((Fala 'm6' "Alex! Eu t${oc} aqui! T${oc} vivo!" 0), 'v_vivo', .84, 1.05, .6)
[S]::VSussurro((Fala 's1' "n${at}o responda" -2), 'v_sus_nao', 1.2)
[S]::VSussurro((Fala 's2' "eu vi voc${ec} cair" -2), 'v_sus_cair', 1.2)
[S]::VSussurro((Fala 's3' "atr${a1}s de voc${ec}" -2), 'v_sus_atras', 1.2)
[S]::VCoro(@((Join-Path $tmp 's1.wav'), (Join-Path $tmp 's2.wav'), (Join-Path $tmp 's3.wav'), (Join-Path $tmp 'm1.wav'), (Join-Path $tmp 'm3.wav')), 'v_coro')
[S]::VRadio((Fala 'r1' "Torre quatro, aqui ${e1} a guarda florestal de Cold Holler. Estou te ouvindo. Escuta com aten${cc}${at}o. N${at}o fica a${i1}. Desce pela estrada de servi${cc}o, atravessa a ponte e segue para leste, at${e1} as luzes da cidade." 1), 'v_guarda1', .74, .5)
[S]::VRadio((Fala 'r2' "E n${at}o responde pra ningu${e1}m. Ningu${e1}m que voc${ec} encontrar a${i1} vai saber o seu nome." 0), 'v_guarda2', .74, .6)
[S]::VRadio((Fala 'r3' "Torre quatro. Aqui ${e1} a comandante. Fique onde est${a1}. Eu estou subindo." -3), 'v_falsa', .8, .9)
[S]::VGente((Fala 't1' "Ei! Meu Deus. Voc${ec} t${a1} bem? Entra a${i1}, eu te levo pra cidade." 1), 'v_motorista1', .72)
[S]::VGente((Fala 't2' "Entra logo. Alex." -4), 'v_motorista2', .66)
$sint.Dispose()
Remove-Item -Recurse -Force $tmp
Get-ChildItem $saida -Filter *.wav | Measure-Object Length -Sum | ForEach-Object { "{0} arquivos, {1:N1} MB" -f $_.Count, ($_.Sum/1MB) }
