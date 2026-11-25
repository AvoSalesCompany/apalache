# Desenha o icone do jogo (PNG 512 e ICO com varios tamanhos).
$raiz = Split-Path -Parent $PSScriptRoot
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.IO;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;

public static class Icone {
  static float Ru(Random r, double a, double b) { return (float)(a + r.NextDouble() * (b - a)); }

  static void Pinheiro(Graphics g, Brush br, float x, float baseY, float h, float larg, Random r) {
    int n = 9;
    using (GraphicsPath p = new GraphicsPath()) {
      PointF[] e = new PointF[n * 2 + 1], d = new PointF[n * 2 + 1];
      for (int i = 0; i < n; i++) {
        float t = (i + 1) / (float)n;
        float w = larg * t * Ru(r, .82, 1.12);
        e[i * 2] = new PointF(x - w, baseY - h + h * t);
        e[i * 2 + 1] = new PointF(x - w * .45f, baseY - h + h * t - h * .02f);
      }
      System.Collections.Generic.List<PointF> pts = new System.Collections.Generic.List<PointF>();
      pts.Add(new PointF(x, baseY - h - h * .05f));
      for (int i = 0; i < n; i++) { float t = (i + 1) / (float)n, w = larg * t * Ru(r, .82, 1.12); pts.Add(new PointF(x + w, baseY - h + h * t)); pts.Add(new PointF(x + w * .45f, baseY - h + h * t - h * .015f)); }
      for (int i = n - 1; i >= 0; i--) { float t = (i + 1) / (float)n, w = larg * t * Ru(r, .82, 1.12); pts.Add(new PointF(x - w * .45f, baseY - h + h * t - h * .015f)); pts.Add(new PointF(x - w, baseY - h + h * t)); }
      p.AddPolygon(pts.ToArray());
      g.FillPath(br, p);
    }
  }

  public static Bitmap Desenha(int S) {
    Bitmap b = new Bitmap(S, S, PixelFormat.Format32bppArgb);
    using (Graphics g = Graphics.FromImage(b)) {
      g.SmoothingMode = SmoothingMode.AntiAlias;
      g.Clear(Color.Transparent);
      float k = S / 512f;
      using (GraphicsPath rr = new GraphicsPath()) {
        float rd = 108 * k, d = rd * 2;
        rr.AddArc(0, 0, d, d, 180, 90); rr.AddArc(S - d - 1, 0, d, d, 270, 90); rr.AddArc(S - d - 1, S - d - 1, d, d, 0, 90); rr.AddArc(0, S - d - 1, d, d, 90, 90); rr.CloseFigure();
        g.SetClip(rr);
        using (LinearGradientBrush ceu = new LinearGradientBrush(new Rectangle(0, 0, S, S), Color.FromArgb(255, 10, 16, 30), Color.FromArgb(255, 34, 56, 92), 90f)) g.FillRectangle(ceu, 0, 0, S, S);
        // halo e lua
        for (int i = 14; i > 0; i--) { float q = (118 + i * 13) * k; using (SolidBrush h = new SolidBrush(Color.FromArgb(9, 190, 212, 255))) g.FillEllipse(h, 256 * k - q, 178 * k - q, q * 2, q * 2); }
        using (SolidBrush lua = new SolidBrush(Color.FromArgb(255, 232, 234, 236))) g.FillEllipse(lua, (256 - 112) * k, (178 - 112) * k, 224 * k, 224 * k);
        Random rl = new Random(9);
        using (GraphicsPath cl = new GraphicsPath()) {
          cl.AddEllipse((256 - 112) * k, (178 - 112) * k, 224 * k, 224 * k);
          GraphicsState st = g.Save(); g.SetClip(cl, CombineMode.Intersect);
          for (int i = 0; i < 16; i++) { float x = Ru(rl, 150, 350), y = Ru(rl, 80, 280), q = Ru(rl, 8, 42); using (SolidBrush cr = new SolidBrush(Color.FromArgb(26, 90, 100, 120))) g.FillEllipse(cr, (x - q) * k, (y - q) * k, q * 2 * k, q * 2 * k); }
          g.Restore(st);
        }
        // mata ao fundo e na frente
        Random r = new Random(31);
        using (SolidBrush f = new SolidBrush(Color.FromArgb(255, 18, 30, 50))) for (int i = 0; i < 12; i++) Pinheiro(g, f, (i * 46 + Ru(r, -8, 8)) * k, 540 * k, Ru(r, 190, 290) * k, Ru(r, 34, 46) * k, r);
        using (SolidBrush f = new SolidBrush(Color.FromArgb(255, 5, 8, 14))) {
          float[] xs = { -6, 66, 128, 392, 452, 520 }; float[] hs = { 400, 320, 230, 240, 340, 420 };
          for (int i = 0; i < xs.Length; i++) Pinheiro(g, f, xs[i] * k, 560 * k, hs[i] * k, 66 * k, r);
          g.FillRectangle(f, 0, 452 * k, S, S);
        }
        // a figura: alta, cabeca caida, olhos que devolvem a luz
        using (SolidBrush f = new SolidBrush(Color.FromArgb(255, 2, 3, 6))) {
          g.FillEllipse(f, 234 * k, 238 * k, 46 * k, 62 * k);
          PointF[] corpo = { new PointF(250, 290), new PointF(270, 290), new PointF(274, 316), new PointF(318, 336), new PointF(326, 470), new PointF(330, 512), new PointF(182, 512), new PointF(188, 470), new PointF(196, 336), new PointF(244, 316) };
          for (int i = 0; i < corpo.Length; i++) corpo[i] = new PointF(corpo[i].X * k, corpo[i].Y * k);
          g.FillPolygon(f, corpo);
        }
        foreach (float ex in new float[] { 247, 268 }) {
          for (int i = 5; i > 0; i--) using (SolidBrush h = new SolidBrush(Color.FromArgb(34, 235, 255, 200))) g.FillEllipse(h, (ex - 3.2f * i) * k, (266 - 3.2f * i) * k, 6.4f * i * k, 6.4f * i * k);
          using (SolidBrush o = new SolidBrush(Color.FromArgb(255, 250, 255, 232))) g.FillEllipse(o, (ex - 5) * k, 261 * k, 10 * k, 10 * k);
        }
        g.ResetClip();
      }
    }
    return b;
  }

  public static void Salva(string png, string ico) {
    using (Bitmap g = Desenha(1024)) {
      Bitmap p = new Bitmap(512, 512); using (Graphics q = Graphics.FromImage(p)) { q.InterpolationMode = InterpolationMode.HighQualityBicubic; q.DrawImage(g, 0, 0, 512, 512); } p.Save(png, ImageFormat.Png);
      int[] ts = { 16, 24, 32, 48, 64, 128, 256 };
      byte[][] im = new byte[ts.Length][];
      for (int i = 0; i < ts.Length; i++) { using (Bitmap m = new Bitmap(ts[i], ts[i])) { using (Graphics q = Graphics.FromImage(m)) { q.InterpolationMode = InterpolationMode.HighQualityBicubic; q.PixelOffsetMode = PixelOffsetMode.HighQuality; q.DrawImage(g, 0, 0, ts[i], ts[i]); } using (MemoryStream s = new MemoryStream()) { m.Save(s, ImageFormat.Png); im[i] = s.ToArray(); } } }
      using (BinaryWriter w = new BinaryWriter(File.Create(ico))) {
        w.Write((short)0); w.Write((short)1); w.Write((short)ts.Length); int off = 6 + 16 * ts.Length;
        for (int i = 0; i < ts.Length; i++) { w.Write((byte)(ts[i] == 256 ? 0 : ts[i])); w.Write((byte)(ts[i] == 256 ? 0 : ts[i])); w.Write((byte)0); w.Write((byte)0); w.Write((short)1); w.Write((short)32); w.Write(im[i].Length); w.Write(off); off += im[i].Length; }
        foreach (byte[] x in im) w.Write(x);
      }
    }
  }
}
'@
New-Item -ItemType Directory -Force (Join-Path $raiz 'instalador') | Out-Null
[Icone]::Salva((Join-Path $raiz 'jogo\tex\icone.png'), (Join-Path $raiz 'instalador\holler.ico'))
Copy-Item (Join-Path $raiz 'instalador\holler.ico') (Join-Path $raiz 'jogo\tex\icone.ico') -Force
