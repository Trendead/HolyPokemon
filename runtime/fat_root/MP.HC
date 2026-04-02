#include "C:GB3.HC"

#define MP_W 160
#define MP_H 144
#define MP_SCALE 2
#define MP_PAD_X 2
#define MP_PAD_Y 2

class MPState
{
  GBCpu cpu;
  U8 fb[MP_W * MP_H];
  U8 btn_low;
  U8 dpad_low;
  I64 step_quanta;
  I64 sleep_ms;
  I64 save_tick;
  Bool quit;
  Bool ready;
};

MPState mp;

U8 MPShade(U8 cid, U8 bgp)
{
  I64 shade;
  shade = (bgp >> (cid * 2)) & 3;
  if (shade == 0) return 255;
  if (shade == 1) return 170;
  if (shade == 2) return 85;
  return 0;
}

I64 MPColor(U8 pix)
{
  if (pix >= 220) return WHITE;
  if (pix >= 140) return LTGRAY;
  if (pix >= 60) return DKGRAY;
  return BLACK;
}

U8 MPTilePix(I64 px, I64 py, U16 map_base, I64 signed_mode)
{
  I64 tx;
  I64 ty;
  I64 tidx;
  I64 raw;
  I64 tnum;
  I64 taddr;
  I64 row;
  I64 lo;
  I64 hi;
  I64 bit;
  I64 cid;

  tx = (px & 255) >> 3;
  ty = (py & 255) >> 3;
  tidx = map_base + ty * 32 + tx;
  raw = mp.cpu.ram[tidx & 0xFFFF];
  tnum = raw;
  if (signed_mode && raw >= 128)
    tnum = raw - 256;
  if (signed_mode)
    taddr = 0x9000 + tnum * 16;
  else
    taddr = 0x8000 + tnum * 16;
  row = py & 7;
  lo = mp.cpu.ram[(taddr + row * 2) & 0xFFFF];
  hi = mp.cpu.ram[(taddr + row * 2 + 1) & 0xFFFF];
  bit = 7 - (px & 7);
  cid = ((hi >> bit) & 1) << 1;
  cid |= (lo >> bit) & 1;
  return cid & 3;
}

U8 MPObjShade(I64 x, I64 y, U8 bg_cid, U8 bg_px)
{
  I64 o;
  I64 oidx;
  I64 ox;
  I64 oy;
  I64 px;
  I64 py;
  I64 obj_h;
  I64 row;
  I64 bit;
  U8 t;
  U8 atb;
  U8 lo;
  U8 hi;
  U8 ocid;
  U8 pal;

  if (!(mp.cpu.ram[0xFF40] & 0x02))
    return bg_px;

  obj_h = 8;
  if (mp.cpu.ram[0xFF40] & 0x04)
    obj_h = 16;

  for (o = 0; o < 40; o++)
  {
    oidx = 0xFE00 + (o << 2);
    oy = mp.cpu.ram[oidx] - 16;
    ox = mp.cpu.ram[oidx + 1] - 8;
    if (!(x < ox || x >= ox + 8 || y < oy || y >= oy + obj_h))
    {
      t = mp.cpu.ram[oidx + 2];
      atb = mp.cpu.ram[oidx + 3];
      px = x - ox;
      py = y - oy;
      if (atb & 0x20)
        px = 7 - px;
      if (atb & 0x40)
        py = (obj_h - 1) - py;
      if (obj_h == 16)
      {
        t &= 0xFE;
        if (py >= 8)
        {
          t++;
          py -= 8;
        }
      }
      row = py & 7;
      lo = mp.cpu.ram[(0x8000 + t * 16 + row * 2) & 0xFFFF];
      hi = mp.cpu.ram[(0x8000 + t * 16 + row * 2 + 1) & 0xFFFF];
      bit = 7 - (px & 7);
      ocid = ((hi >> bit) & 1) << 1;
      ocid |= (lo >> bit) & 1;
      if (ocid)
      {
        if (!((atb & 0x80) && bg_cid))
        {
          pal = mp.cpu.ram[0xFF48];
          if (atb & 0x10)
            pal = mp.cpu.ram[0xFF49];
          return MPShade(ocid & 3, pal);
        }
      }
    }
  }
  return bg_px;
}

U0 MPBuildFrame()
{
  I64 x;
  I64 y;
  I64 bx;
  I64 by;
  I64 cx;
  I64 cy;
  U8 bg_cid;
  U8 bg_px;

  for (y = 0; y < MP_H; y++)
  {
    for (x = 0; x < MP_W; x++)
    {
      bg_cid = 0;
      bg_px = MPShade(0, mp.cpu.ram[0xFF47]);
      if (mp.cpu.ram[0xFF40] & 0x01)
      {
        bx = (x + mp.cpu.ram[0xFF43]) & 255;
        by = (y + mp.cpu.ram[0xFF42]) & 255;
        if (mp.cpu.ram[0xFF40] & 0x08)
        {
          if (mp.cpu.ram[0xFF40] & 0x10)
            bg_cid = MPTilePix(bx, by, 0x9C00, 0);
          else
            bg_cid = MPTilePix(bx, by, 0x9C00, 1);
        }
        else
        {
          if (mp.cpu.ram[0xFF40] & 0x10)
            bg_cid = MPTilePix(bx, by, 0x9800, 0);
          else
            bg_cid = MPTilePix(bx, by, 0x9800, 1);
        }
        bg_px = MPShade(bg_cid, mp.cpu.ram[0xFF47]);
        if ((mp.cpu.ram[0xFF40] & 0x20) &&
            y >= mp.cpu.ram[0xFF4A] &&
            x >= (mp.cpu.ram[0xFF4B] - 7))
        {
          cx = x - (mp.cpu.ram[0xFF4B] - 7);
          cy = y - mp.cpu.ram[0xFF4A];
          if (mp.cpu.ram[0xFF40] & 0x40)
          {
            if (mp.cpu.ram[0xFF40] & 0x10)
              bg_cid = MPTilePix(cx, cy, 0x9C00, 0);
            else
              bg_cid = MPTilePix(cx, cy, 0x9C00, 1);
          }
          else
          {
            if (mp.cpu.ram[0xFF40] & 0x10)
              bg_cid = MPTilePix(cx, cy, 0x9800, 0);
            else
              bg_cid = MPTilePix(cx, cy, 0x9800, 1);
          }
          bg_px = MPShade(bg_cid, mp.cpu.ram[0xFF47]);
        }
      }
      bg_px = MPObjShade(x, y, bg_cid, bg_px);
      mp.fb[y * MP_W + x] = bg_px;
    }
  }
}

U0 MPDraw(CTask *task, CDC *dc)
{
  I64 x;
  I64 y;
  dc->color = BLACK;
  GrRect(dc, MP_PAD_X - 1, MP_PAD_Y - 1, MP_W * MP_SCALE + 2, MP_H * MP_SCALE + 2);
  if (!mp.ready)
    return;
  for (y = 0; y < MP_H; y++)
  {
    for (x = 0; x < MP_W; x++)
    {
      dc->color = MPColor(mp.fb[y * MP_W + x]);
      GrRect(dc, MP_PAD_X + x * MP_SCALE, MP_PAD_Y + y * MP_SCALE, MP_SCALE, MP_SCALE);
    }
  }
}

U0 MPStep(I64 n)
{
  I64 i;
  for (i = 0; i < n; i++)
    GBCpuStep(&mp.cpu);
}

U0 MPSetBtnBit(U8 mask, Bool down)
{
  if (down)
    mp.btn_low &= ~mask;
  else
    mp.btn_low |= mask;
}

U0 MPSetDpadBit(U8 mask, Bool down)
{
  if (down)
    mp.dpad_low &= ~mask;
  else
    mp.dpad_low |= mask;
}

U0 MPFrameTask(U8 *unused)
{
  while (!mp.quit)
  {
    GBJoySetState(&mp.cpu, mp.btn_low, mp.dpad_low);
    MPStep(mp.step_quanta);
    mp.save_tick++;
    if (mp.save_tick >= 180)
    {
      GBCpuFlushSave(&mp.cpu, FALSE);
      mp.save_tick = 0;
    }
    MPBuildFrame();
    Sleep(mp.sleep_ms);
  }
  GBCpuFlushSave(&mp.cpu, TRUE);
}

U0 HolyRedManualPlay()
{
  I64 ch;
  I64 sc;
  U8 *rom;
  I64 rom_size;
  I64 arg1;
  I64 arg2;

  SettingsPush;
  WinBorder;
  StrCpy(Fs->task_name, "Red");
  StrCpy(Fs->task_title, "Pokemon Red");
  Fs->win_left = 2;
  Fs->win_top = 2;
  Fs->win_right = 78;
  Fs->win_bottom = 60;
  DocCursor;
  DocClear;
  Fs->draw_it = &MPDraw;

  rom = FileRead("C:POKEMON.GB", &rom_size);
  if (!rom || rom_size <= 0)
  {
    Print("Missing ROM C:POKEMON.GB\n");
    SettingsPop;
    return;
  }

  MemSet(&mp, 0, sizeof(MPState));
  GBCpuInitFromRom(&mp.cpu, rom, rom_size);
  mp.btn_low = 0x0F;
  mp.dpad_low = 0x0F;
  mp.step_quanta = 60000;
  mp.sleep_ms = 1;
  mp.save_tick = 0;
  mp.cpu.save_dirty = 1;
  GBJoySetState(&mp.cpu, mp.btn_low, mp.dpad_low);
  MPStep(7000000);
  MPBuildFrame();
  mp.ready = TRUE;
  mp.quit = FALSE;
  Spawn(&MPFrameTask, NULL, "MP Frame",,);

  Print("Arrows=D-Pad  Z=A  X=B  A=Start  S=Select\n");
  Print("W=faster  Q=slower\n");
  Print("Shift-Esc exits.\n");

  try
  {
    while (TRUE)
    {
      switch (GetMsg(&arg1, &arg2, (1 << MSG_KEY_DOWN) | (1 << MSG_KEY_UP)))
      {
        case MSG_KEY_DOWN:
          ch = arg1;
          sc = arg2;
          if (ch == CH_SHIFT_ESC)
            goto done;
          switch (ch)
          {
            case 'z':
            case 'Z':
              MPSetBtnBit(0x01, TRUE);
              break;
            case 'x':
            case 'X':
              MPSetBtnBit(0x02, TRUE);
              break;
            case 'a':
            case 'A':
              MPSetBtnBit(0x08, TRUE);
              break;
            case 's':
            case 'S':
              MPSetBtnBit(0x04, TRUE);
              break;
            case 'w':
            case 'W':
              if (mp.step_quanta < 220000)
                mp.step_quanta += 10000;
              if (mp.sleep_ms > 0)
                mp.sleep_ms--;
              break;
            case 'q':
            case 'Q':
              if (mp.step_quanta > 12000)
                mp.step_quanta -= 10000;
              if (mp.sleep_ms < 20)
                mp.sleep_ms++;
              break;
            case 0:
              if (sc.u8[0] == SC_CURSOR_UP)
                MPSetDpadBit(0x04, TRUE);
              else if (sc.u8[0] == SC_CURSOR_RIGHT)
                MPSetDpadBit(0x01, TRUE);
              else if (sc.u8[0] == SC_CURSOR_DOWN)
                MPSetDpadBit(0x08, TRUE);
              else if (sc.u8[0] == SC_CURSOR_LEFT)
                MPSetDpadBit(0x02, TRUE);
              break;
          }
          break;
        case MSG_KEY_UP:
          ch = arg1;
          sc = arg2;
          switch (ch)
          {
            case 'z':
            case 'Z':
              MPSetBtnBit(0x01, FALSE);
              break;
            case 'x':
            case 'X':
              MPSetBtnBit(0x02, FALSE);
              break;
            case 'a':
            case 'A':
              MPSetBtnBit(0x08, FALSE);
              break;
            case 's':
            case 'S':
              MPSetBtnBit(0x04, FALSE);
              break;
            case 0:
              if (sc.u8[0] == SC_CURSOR_UP)
                MPSetDpadBit(0x04, FALSE);
              else if (sc.u8[0] == SC_CURSOR_RIGHT)
                MPSetDpadBit(0x01, FALSE);
              else if (sc.u8[0] == SC_CURSOR_DOWN)
                MPSetDpadBit(0x08, FALSE);
              else if (sc.u8[0] == SC_CURSOR_LEFT)
                MPSetDpadBit(0x02, FALSE);
              break;
          }
          break;
      }
    }
done:
    mp.quit = TRUE;
    Sleep(30);
  }
  catch
  {
    PutExcept;
  }
  SettingsPop;
}

HolyRedManualPlay;
