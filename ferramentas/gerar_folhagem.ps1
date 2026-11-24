# Desenha as texturas de folhagem com transparencia (galhos, agulhas, folhas).
$raiz = Split-Path -Parent $PSScriptRoot
$saida = Join-Path $raiz 'jogo\tex'
New-Item -ItemType Directory -Force $saida | Out-Null

Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;

public static class Folhagem {
  static Random R;
  static float F(double a, double b) { return (float)(a + R.NextDouble() * (b - a)); }
  static Color Var(int r, int g, int b, double v) {
    double k = 1.0 + (R.NextDouble() * 2 - 1) * v;
    return Color.FromArgb(255, C(r * k), C(g * k), C(b * k));
  }
  static int C(double v) { return v < 0 ? 0 : (v > 255 ? 255 : (int)v); }
  static Graphics G(Bitmap b) {
    Graphics g = Graphics.FromImage(b);
    g.SmoothingMode = SmoothingMode.AntiAlias;
    g.Clear(Color.Transparent);
    return g;
  }
  static void Linha(Graphics g, Color c, float w, float x0, float y0, float x1, float y1) {
    using (Pen p = new Pen(c, w)) { p.StartCap = LineCap.Round; p.EndCap = LineCap.Triangle; g.DrawLine(p, x0, y0, x1, y1); }
  }

  // ---- ramo de conifera (abeto/tsuga): raiz na esquerda, ponta na direita
  static void Agulhas(Graphics g, float x, float y, float ang, float len, double esc) {
    int n = (int)(len / 2.6);
    for (int i = 0; i < n; i++) {
      float t = i / (float)n;
      float px = x + (float)Math.Cos(ang) * len * t, py = y + (float)Math.Sin(ang) * len * t;
      float nl = (float)(F(9, 15) * esc * (1.0 - 0.45 * t));
      for (int s = -1; s <= 1; s += 2) {
        float a = ang + s * F(0.65, 1.15);
        Color c = R.NextDouble() < 0.12 ? Var(92, 98, 56, .2) : Var(38, 62, 40, .35);
        Linha(g, c, F(1.5, 2.4), px, py, px + (float)Math.Cos(a) * nl, py + (float)Math.Sin(a) * nl);
      }
    }
  }
  public static void Conifera(string f) {
    R = new Random(11);
    using (Bitmap b = new Bitmap(1024, 512)) using (Graphics g = G(b)) {
      for (int pass = 0; pass < 2; pass++) {
        R = new Random(11 + pass * 5);
        int n = 34;
        for (int i = 0; i < n; i++) {
          float t = (i + 1) / (float)(n + 1);
          float x = 10 + t * 960, y = 256 + (float)Math.Sin(t * 3.1) * 14;
          float env = (float)(Math.Sin(Math.Pow(t, 0.62) * 3.1415) * 0.9 + 0.12);
          float len = 250 * env * F(.72, 1.05);
          for (int s = -1; s <= 1; s += 2) {
            float a = s * F(.72, 1.0);
            if (pass == 0) {
              Linha(g, Var(52, 40, 30, .2), 3.2f, x, y, x + (float)Math.Cos(a) * len * .95f, y + (float)Math.Sin(a) * len * .95f);
            }
            Agulhas(g, x, y, a, len, 1.0);
            int sub = (int)(len / 55);
            for (int k = 1; k <= sub; k++) {
              float tt = k / (float)(sub + 1);
              float sx = x + (float)Math.Cos(a) * len * tt, sy = y + (float)Math.Sin(a) * len * tt;
              Agulhas(g, sx, sy, a + F(.45, .75), len * .30f * (1.2f - tt), .85);
              Agulhas(g, sx, sy, a - F(.45, .75), len * .30f * (1.2f - tt), .85);
            }
          }
        }
        Linha(g, Var(50, 38, 28, .1), 7f, 0, 256, 620, 262);
        Linha(g, Var(50, 38, 28, .1), 4f, 600, 262, 1000, 258);
        Agulhas(g, 560, 258, 0f, 440, 1.0);
      }
      b.Save(f, ImageFormat.Png);
    }
  }

  // ---- galhos nus (arvore de folha caduca no fim do outono)
  static void Galho(Graphics g, float x, float y, float ang, float len, float w, int n) {
    if (n == 0 || len < 8) return;
    float cx = x, cy = y, a = ang; int seg = 7;
    for (int i = 0; i < seg; i++) {
      a += F(-.16, .16);
      float nx = cx + (float)Math.Cos(a) * len / seg, ny = cy + (float)Math.Sin(a) * len / seg;
      float ww = Math.Max(1.3f, w * (1f - i / (float)seg * .55f));
      Linha(g, Var(64, 56, 50, .22), ww, cx, cy, nx, ny);
      cx = nx; cy = ny;
      if (i > 0 && R.NextDouble() < .82) {
        float side = R.NextDouble() < .5 ? -1 : 1;
        Galho(g, cx, cy, a + side * F(.38, .95), len * F(.36, .60), ww * .62f, n - 1);
      }
    }
    Galho(g, cx, cy, a + F(-.3, .3), len * .55f, w * .45f, n - 1);
  }
  public static void Galhos(string f) {
    R = new Random(5);
    using (Bitmap b = new Bitmap(1024, 1024)) using (Graphics g = G(b)) {
      Galho(g, 512, 1020, -1.57f, 640, 15, 5);
      Galho(g, 512, 1010, -2.05f, 470, 10, 4);
      Galho(g, 512, 1010, -1.05f, 480, 10, 4);
      b.Save(f, ImageFormat.Png);
    }
  }

  // ---- folhas
  static void Folha(Graphics g, float x, float y, float ang, float len, float larg, Color c1, Color c2) {
    GraphicsState st = g.Save();
    g.TranslateTransform(x, y); g.RotateTransform(ang * 57.2958f);
    using (GraphicsPath p = new GraphicsPath()) {
      p.AddBezier(0, 0, len * .25f, -larg, len * .75f, -larg * .95f, len, 0);
      p.AddBezier(len, 0, len * .75f, larg * .95f, len * .25f, larg, 0, 0);
      using (LinearGradientBrush br = new LinearGradientBrush(new PointF(0, -larg), new PointF(0, larg), c1, c2)) g.FillPath(br, p);
    }
    Linha(g, Color.FromArgb(150, C(c1.R * 1.5), C(c1.G * 1.45), C(c1.B * 1.2)), 2.2f, 0, 0, len * .95f, 0);
    for (int i = 2; i < 10; i++) {
      float t = i / 11f;
      for (int s = -1; s <= 1; s += 2)
        Linha(g, Color.FromArgb(60, C(c1.R * 1.5), C(c1.G * 1.4), C(c1.B * 1.2)), 1.1f, len * t, 0, len * (t + .09f), s * larg * .7f * (float)Math.Sin(t * 3.14));
    }
    g.Restore(st);
  }
  public static void Rododendro(string f) {
    R = new Random(21);
    using (Bitmap b = new Bitmap(1024, 1024)) using (Graphics g = G(b)) {
      for (int k = 0; k < 9; k++) {
        double a0 = k == 8 ? 0 : k * Math.PI * 2 / 8;
        float cx = k == 8 ? 512 : 512 + (float)Math.Cos(a0) * 265, cy = k == 8 ? 512 : 512 + (float)Math.Sin(a0) * 265;
        int n = 11;
        float rot = F(0, 6);
        for (int i = 0; i < n; i++) {
          float a = rot + i * 6.2832f / n + F(-.18, .18);
          float len = F(150, 225);
          Folha(g, cx, cy, a, len, len * F(.15, .20), Var(40, 62, 36, .28), Var(24, 42, 26, .28));
        }
        for (int i = 0; i < 6; i++) {
          float a = rot + .3f + i * 6.2832f / 6;
          Folha(g, cx, cy, a, F(80, 110), 17, Var(58, 82, 44, .2), Var(38, 58, 34, .2));
        }
      }
      b.Save(f, ImageFormat.Png);
    }
  }
  public static void FolhasSecas(string f) {
    R = new Random(33);
    using (Bitmap b = new Bitmap(1024, 1024)) using (Graphics g = G(b)) {
      Galho(g, 512, 1020, -1.57f, 560, 8, 4);
      for (int i = 0; i < 120; i++) {
        double rr = Math.Sqrt(R.NextDouble()) * 430, aa = R.NextDouble() * 6.28;
        float len = F(60, 110);
        Folha(g, 512 + (float)(Math.Cos(aa) * rr), 480 + (float)(Math.Sin(aa) * rr), F(0, 6.28), len, len * F(.22, .34), Var(112, 72, 38, .35), Var(74, 46, 26, .35));
      }
      b.Save(f, ImageFormat.Png);
    }
  }
  public static void Capim(string f) {
    R = new Random(44);
    using (Bitmap b = new Bitmap(512, 512)) using (Graphics g = G(b)) {
      for (int i = 0; i < 90; i++) {
        float x = 256 + F(-110, 110), h = F(180, 490), curva = F(-130, 130) + (x - 256) * .7f;
        Color c = R.NextDouble() < .6 ? Var(104, 92, 58, .3) : Var(62, 72, 40, .3);
        using (GraphicsPath p = new GraphicsPath()) {
          float w = F(3, 6);
          p.AddBezier(x - w, 512, x - w, 512 - h * .5f, x + curva * .4f, 512 - h * .85f, x + curva, 512 - h);
          p.AddBezier(x + curva, 512 - h, x + curva * .4f + w, 512 - h * .8f, x + w, 512 - h * .5f, x + w, 512);
          using (SolidBrush br = new SolidBrush(c)) g.FillPath(br, p);
        }
      }
      b.Save(f, ImageFormat.Png);
    }
  }
  public static void FolhaSolta(string f) {
    R = new Random(3);
    using (Bitmap b = new Bitmap(128, 128)) using (Graphics g = G(b)) {
      Folha(g, 8, 64, 0, 112, 34, Color.FromArgb(255, 128, 84, 42), Color.FromArgb(255, 84, 52, 28));
      b.Save(f, ImageFormat.Png);
    }
  }
  // ---- fumaca macia com ruido
  static double Ru(double[,] t, double x, double y) {
    int n = t.GetLength(0); int xi = (int)Math.Floor(x), yi = (int)Math.Floor(y);
    double fx = x - xi, fy = y - yi; fx = fx * fx * (3 - 2 * fx); fy = fy * fy * (3 - 2 * fy);
    int a = ((xi % n) + n) % n, b = (a + 1) % n, c = ((yi % n) + n) % n, d = (c + 1) % n;
    return (t[a, c] * (1 - fx) + t[b, c] * fx) * (1 - fy) + (t[a, d] * (1 - fx) + t[b, d] * fx) * fy;
  }
  public static void Fumaca(string f) {
    R = new Random(77); double[,] t = new double[64, 64];
    for (int i = 0; i < 64; i++) for (int j = 0; j < 64; j++) t[i, j] = R.NextDouble();
    int S = 256;
    using (Bitmap b = new Bitmap(S, S)) {
      for (int y = 0; y < S; y++) for (int x = 0; x < S; x++) {
        double u = x / (double)S * 2 - 1, v = y / (double)S * 2 - 1, r = Math.Sqrt(u * u + v * v);
        double n = 0, a = .5, fr = 4; for (int k = 0; k < 5; k++) { n += a * Ru(t, x / (double)S * fr + k * 7, y / (double)S * fr + k * 3); a *= .5; fr *= 2; }
        double m = Math.Max(0, 1 - r); m = m * m * (3 - 2 * m);
        double al = Math.Max(0, Math.Min(1, m * (n * 1.9 - .25)));
        b.SetPixel(x, y, Color.FromArgb(C(al * 255), 255, 255, 255));
      }
      b.Save(f, ImageFormat.Png);
    }
  }
  // ---- placa com texto (usada em placas, lapides, avisos)
  public static void Placa(string f, int w, int h, string txt, string fonte, float tam, int fr, int fg, int fb, int br, int bg, int bb, double sujeira) {
    R = new Random(w + h + txt.Length);
    using (Bitmap b = new Bitmap(w, h)) using (Graphics g = Graphics.FromImage(b)) {
      g.SmoothingMode = SmoothingMode.AntiAlias; g.TextRenderingHint = System.Drawing.Text.TextRenderingHint.AntiAliasGridFit;
      g.Clear(Color.FromArgb(255, br, bg, bb));
      using (Font ft = new Font(fonte, tam, FontStyle.Bold, GraphicsUnit.Pixel)) using (SolidBrush sb = new SolidBrush(Color.FromArgb(255, fr, fg, fb))) {
        StringFormat sf = new StringFormat(); sf.Alignment = StringAlignment.Center; sf.LineAlignment = StringAlignment.Center;
        g.DrawString(txt, ft, sb, new RectangleF(0, 0, w, h), sf);
      }
      for (int i = 0; i < (int)(sujeira * 900); i++) {
        float x = F(0, w), y = F(0, h), s = F(1, 14);
        using (SolidBrush sb = new SolidBrush(Color.FromArgb((int)F(8, 46), C(br * .5), C(bg * .42), C(bb * .35)))) g.FillEllipse(sb, x, y, s, s * F(.5, 3));
      }
      b.Save(f, ImageFormat.Png);
    }
  }
}
'@

[Folhagem]::Conifera("$saida\fol_conifera.png")
[Folhagem]::Galhos("$saida\fol_galhos.png")
[Folhagem]::Rododendro("$saida\fol_rododendro.png")
[Folhagem]::FolhasSecas("$saida\fol_secas.png")
[Folhagem]::Capim("$saida\fol_capim.png")
[Folhagem]::FolhaSolta("$saida\fol_folha.png")
[Folhagem]::Fumaca("$saida\fumaca.png")
$nl = "`n"
[Folhagem]::Placa("$saida\placa_cidade.png", 1024, 512, "COLD HOLLER${nl}POP. 312", 'Arial', 120, 235, 240, 235, 18, 74, 48, 1.4)
[Folhagem]::Placa("$saida\placa_posto.png", 1024, 256, 'HOLLER GAS', 'Arial Black', 130, 250, 238, 214, 150, 24, 22, .6)
[Folhagem]::Placa("$saida\placa_torre.png", 512, 256, "TORRE DE INC$([char]0xCA)NDIO${nl}CHAVE COM O GUARDA", 'Arial', 38, 226, 214, 180, 66, 46, 30, 2.0)
[Folhagem]::Placa("$saida\placa_regras.png", 512, 640, "N$([char]0xC3)O GRITE.${nl}N$([char]0xC3)O RESPONDA.${nl}N$([char]0xC3)O SIGA AS LUZES.${nl}SE O MATO CALAR,${nl}CALE TAMB$([char]0xC9)M.", 'Georgia', 46, 24, 14, 10, 112, 86, 60, 2.0)
[Folhagem]::Placa("$saida\placa_cinto.png", 256, 128, 'APERTE OS CINTOS', 'Arial', 25, 255, 214, 120, 26, 18, 10, 0)
[Folhagem]::Placa("$saida\placa_saida.png", 256, 90, "SA$([char]0xCD)DA", 'Arial', 58, 255, 250, 240, 120, 12, 8, 0.2)
[Folhagem]::Placa("$saida\placa_ponte.png", 512, 256, "PONTE ESTREITA${nl}ROD. 19  -  300 m", 'Arial', 52, 20, 18, 14, 206, 160, 40, 2.2)
Get-ChildItem $saida -Filter *.png | Select-Object Name,Length
