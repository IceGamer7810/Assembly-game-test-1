using System;
using System.Diagnostics;
using System.Drawing;
using System.Windows.Forms;

namespace AssemblyGameTest1
{
    internal static class Program
    {
        [STAThread]
        private static void Main()
        {
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            Application.Run(new GameForm());
        }
    }

    internal sealed class GameForm : Form
    {
        private readonly Timer gameTimer;
        private readonly Stopwatch stopwatch;

        private bool keyW;
        private bool keyA;
        private bool keyS;
        private bool keyD;
        private bool keyShift;
        private bool keyCtrl;

        private float playerX;
        private float playerY;
        private float playerZ;
        private float verticalVelocity;

        private const float Gravity = 28.0f;
        private const float JumpVelocity = 10.0f;
        private const float WalkSpeed = 3.8f;
        private const float RunMultiplier = 1.8f;
        private const float CrouchMultiplier = 0.5f;
        private const float PlayerRadius = 18.0f;

        private readonly Color floorColorA = Color.FromArgb(47, 67, 88);
        private readonly Color floorColorB = Color.FromArgb(203, 210, 218);
        private readonly Brush playerBrush = new SolidBrush(Color.FromArgb(231, 111, 81));
        private readonly Brush shadowBrush = new SolidBrush(Color.FromArgb(70, 0, 0, 0));
        private readonly Pen crosshairPen = new Pen(Color.FromArgb(210, 20, 20, 20), 2.0f);

        public GameForm()
        {
            Text = "Assembly Game Test 1 - Win10 EXE";
            ClientSize = new Size(1280, 720);
            MinimumSize = new Size(960, 540);
            StartPosition = FormStartPosition.CenterScreen;
            FormBorderStyle = FormBorderStyle.Sizable;
            BackColor = Color.FromArgb(221, 228, 234);
            DoubleBuffered = true;
            KeyPreview = true;

            playerX = 0.0f;
            playerY = 0.0f;
            playerZ = 0.0f;
            verticalVelocity = 0.0f;

            KeyDown += OnKeyDown;
            KeyUp += OnKeyUp;

            stopwatch = Stopwatch.StartNew();
            gameTimer = new Timer { Interval = 16 };
            gameTimer.Tick += OnTick;
            gameTimer.Start();
        }

        protected override void Dispose(bool disposing)
        {
            if (disposing)
            {
                crosshairPen.Dispose();
                playerBrush.Dispose();
                shadowBrush.Dispose();
                gameTimer.Dispose();
            }

            base.Dispose(disposing);
        }

        private void OnTick(object sender, EventArgs e)
        {
            float dt = (float)stopwatch.Elapsed.TotalSeconds;
            stopwatch.Restart();

            if (dt <= 0.0f)
            {
                return;
            }

            if (dt > 0.05f)
            {
                dt = 0.05f;
            }

            UpdatePlayer(dt);
            Invalidate();
        }

        private void UpdatePlayer(float dt)
        {
            float moveX = 0.0f;
            float moveY = 0.0f;

            if (keyW) moveY -= 1.0f;
            if (keyS) moveY += 1.0f;
            if (keyA) moveX -= 1.0f;
            if (keyD) moveX += 1.0f;

            if (moveX != 0.0f || moveY != 0.0f)
            {
                float invLen = 1.0f / (float)Math.Sqrt(moveX * moveX + moveY * moveY);
                moveX *= invLen;
                moveY *= invLen;

                float speed = WalkSpeed;
                if (keyShift)
                {
                    speed *= RunMultiplier;
                }

                if (keyCtrl)
                {
                    speed *= CrouchMultiplier;
                }

                playerX += moveX * speed * dt;
                playerY += moveY * speed * dt;
            }

            bool grounded = playerZ <= 0.0f;
            if (grounded)
            {
                playerZ = 0.0f;
                if (verticalVelocity < 0.0f)
                {
                    verticalVelocity = 0.0f;
                }
            }

            verticalVelocity -= Gravity * dt;
            playerZ += verticalVelocity * dt;

            if (playerZ < 0.0f)
            {
                playerZ = 0.0f;
                verticalVelocity = 0.0f;
            }
        }

        private void OnKeyDown(object sender, KeyEventArgs e)
        {
            switch (e.KeyCode)
            {
                case Keys.W: keyW = true; break;
                case Keys.A: keyA = true; break;
                case Keys.S: keyS = true; break;
                case Keys.D: keyD = true; break;
                case Keys.ShiftKey: keyShift = true; break;
                case Keys.ControlKey: keyCtrl = true; break;
                case Keys.Space:
                    if (playerZ == 0.0f)
                    {
                        verticalVelocity = JumpVelocity;
                    }
                    break;
            }
        }

        private void OnKeyUp(object sender, KeyEventArgs e)
        {
            switch (e.KeyCode)
            {
                case Keys.W: keyW = false; break;
                case Keys.A: keyA = false; break;
                case Keys.S: keyS = false; break;
                case Keys.D: keyD = false; break;
                case Keys.ShiftKey: keyShift = false; break;
                case Keys.ControlKey: keyCtrl = false; break;
            }
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            base.OnPaint(e);

            Graphics g = e.Graphics;
            g.SmoothingMode = System.Drawing.Drawing2D.SmoothingMode.AntiAlias;

            int width = ClientSize.Width;
            int height = ClientSize.Height;

            DrawCheckerFloor(g, width, height);
            DrawPlayer(g, width, height);
            DrawCrosshair(g, width, height);
            DrawHintText(g);
        }

        private void DrawCheckerFloor(Graphics g, int width, int height)
        {
            float tile = 48.0f;
            float centerX = width * 0.5f;
            float centerY = height * 0.58f;

            int tilesX = (int)Math.Ceiling(width / tile) + 4;
            int tilesY = (int)Math.Ceiling(height / tile) + 4;

            for (int gy = -tilesY; gy <= tilesY; gy++)
            {
                for (int gx = -tilesX; gx <= tilesX; gx++)
                {
                    float screenX = centerX + gx * tile - playerX * tile;
                    float screenY = centerY + gy * tile - playerY * tile;

                    RectangleF rect = new RectangleF(screenX, screenY, tile, tile);
                    bool even = ((gx + gy) & 1) == 0;
                    using (Brush b = new SolidBrush(even ? floorColorA : floorColorB))
                    {
                        g.FillRectangle(b, rect);
                    }
                }
            }
        }

        private void DrawPlayer(Graphics g, int width, int height)
        {
            float centerX = width * 0.5f;
            float centerY = height * 0.58f;

            float crouchScale = keyCtrl ? 0.6f : 1.0f;
            float radius = PlayerRadius * crouchScale;

            float shadowR = PlayerRadius * 0.85f;
            g.FillEllipse(
                shadowBrush,
                centerX - shadowR,
                centerY - shadowR,
                shadowR * 2.0f,
                shadowR * 2.0f);

            float jumpPixels = playerZ * 11.0f;
            g.FillEllipse(
                playerBrush,
                centerX - radius,
                centerY - jumpPixels - radius,
                radius * 2.0f,
                radius * 2.0f);
        }

        private void DrawCrosshair(Graphics g, int width, int height)
        {
            float cx = width * 0.5f;
            float cy = height * 0.5f;
            const float gap = 8.0f;
            const float len = 16.0f;

            g.DrawLine(crosshairPen, cx - len, cy, cx - gap, cy);
            g.DrawLine(crosshairPen, cx + gap, cy, cx + len, cy);
            g.DrawLine(crosshairPen, cx, cy - len, cx, cy - gap);
            g.DrawLine(crosshairPen, cx, cy + gap, cx, cy + len);
        }

        private void DrawHintText(Graphics g)
        {
            const string text = "WASD: Move | SPACE: Jump | SHIFT: Run | CTRL: Crouch";
            using (Font font = new Font("Segoe UI", 10.0f, FontStyle.Bold))
            using (Brush brush = new SolidBrush(Color.FromArgb(220, 15, 15, 15)))
            {
                g.DrawString(text, font, brush, 14.0f, 12.0f);
            }
        }
    }
}
