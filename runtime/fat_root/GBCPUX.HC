

#define GB_CORE_TAG 720
#define GB_EXT_RAM_CAP 0x8000
#define GB_SAVE_PATH "C:/POKEMON.SAV"
#define GB_SAVE_PATH_ALT "C:POKEMON.SAV"

#define GB_CART_MBC1 1
#define GB_CART_MBC3 3

class GBCpu
{
  U8 a, f, b, c, d, e, h, l;
  U16 sp, pc;
  U16 last_pc;
  U16 unsupported_pc;
  U8 ime;
  U8 ime_delay;
  U8 halted;
  U8 stat_lyc_prev;
  U8 last_op;
  U8 unsupported;
  I64 cycle_accum;
  I64 ly_accum;
  I64 tima_accum;
  I64 irq_vblank_raised;
  I64 irq_stat_raised;
  I64 irq_timer_raised;
  I64 irq_vblank_served;
  I64 irq_stat_served;
  I64 irq_timer_served;
  I64 irq_serial_served;
  I64 irq_joy_served;
  I64 pc_loop_hits;
  I64 pc_vblank_entry_hits;
  I64 pc_loop_zero_hits;
  I64 alu_block_hits;
  I64 op_9d_hits;
  U8 *rom;
  I64 rom_size;
  U8 cart_type;
  U8 cart_mbc;
  U8 mbc_rom_bank;
  U8 mbc_ram_bank;
  U8 mbc_ram_enable;
  U8 mbc1_low5;
  U8 mbc1_high2;
  U8 mbc1_mode;
  U8 joy_btn;
  U8 joy_dpad;
  U8 joy_last_low;
  U8 save_dirty;
  I64 ext_ram_size;
  U8 ext_ram[GB_EXT_RAM_CAP];
  U8 ram[0x10000];
};

#define GB_REG_IF 0xFF0F
#define GB_REG_LCDC 0xFF40
#define GB_REG_STAT 0xFF41
#define GB_REG_LY 0xFF44
#define GB_REG_DIV 0xFF04
#define GB_REG_IE 0xFFFF
#define GB_STRICT_LCD_OFF 0

U8 GBJoyCompute(GBCpu *cpu)
{
  U8 sel;
  U8 low;
  sel = cpu->ram[0xFF00] & 0x30;
  low = 0x0F;
  if (!(sel & 0x10))
    low &= cpu->joy_dpad;
  if (!(sel & 0x20))
    low &= cpu->joy_btn;
  return 0xC0 | sel | low;
}

I64 GBCartRamSize(U8 ram_size_code)
{
  switch (ram_size_code)
  {
    case 0x01: return 2 * 1024;
    case 0x02: return 8 * 1024;
    case 0x03: return 32 * 1024;
    case 0x04: return 128 * 1024;
    case 0x05: return 64 * 1024;
  }
  return 0;
}

I64 GBExtRamBankCount(GBCpu *cpu)
{
  if (cpu->ext_ram_size <= 0)
    return 0;
  return (cpu->ext_ram_size + 0x1FFF) / 0x2000;
}

U0 GBCpuLoadSave(GBCpu *cpu)
{
  U8 *data;
  I64 size;
  I64 copy;
  I64 i;

  if (cpu->ext_ram_size <= 0)
    return;

  data = FileRead(GB_SAVE_PATH, &size);
  if (!data || size <= 0)
  {
    if (data)
      Free(data);
    data = FileRead(GB_SAVE_PATH_ALT, &size);
  }
  if (!data || size <= 0)
    return;

  copy = size;
  if (copy > cpu->ext_ram_size)
    copy = cpu->ext_ram_size;
  for (i = 0; i < copy; i++)
    cpu->ext_ram[i] = data[i];
  Free(data);
  cpu->save_dirty = 0;
}

U0 GBCpuFlushSave(GBCpu *cpu, Bool force)
{
  if (cpu->ext_ram_size <= 0)
    return;
  if (!force && !cpu->save_dirty)
    return;
  FileWrite(GB_SAVE_PATH, cpu->ext_ram, cpu->ext_ram_size);
  cpu->save_dirty = 0;
}

U0 GBJoySetState(GBCpu *cpu, U8 btn_low, U8 dpad_low)
{
  U8 old_low;
  U8 new_low;
  old_low = GBJoyCompute(cpu) & 0x0F;
  cpu->joy_btn = btn_low & 0x0F;
  cpu->joy_dpad = dpad_low & 0x0F;
  new_low = GBJoyCompute(cpu) & 0x0F;
  if ((old_low & (~new_low)) & 0x0F)
    cpu->ram[GB_REG_IF] |= 0x10;
  cpu->joy_last_low = new_low;
}

U8 GBBaseCycles(U8 op)
{
  static U8 cyc[256] = {
    4,12,8,8,4,4,8,4,20,8,8,8,4,4,8,4,
    4,12,8,8,4,4,8,4,12,8,8,8,4,4,8,4,
    8,12,8,8,4,4,8,4,8,8,8,8,4,4,8,4,
    8,12,8,8,12,12,12,4,8,8,8,8,4,4,8,4,
    4,4,4,4,4,4,8,4,4,4,4,4,4,4,8,4,
    4,4,4,4,4,4,8,4,4,4,4,4,4,4,8,4,
    4,4,4,4,4,4,8,4,4,4,4,4,4,4,8,4,
    8,8,8,8,8,8,4,8,4,4,4,4,4,4,8,4,
    4,4,4,4,4,4,8,4,4,4,4,4,4,4,8,4,
    4,4,4,4,4,4,8,4,4,4,4,4,4,4,8,4,
    4,4,4,4,4,4,8,4,4,4,4,4,4,4,8,4,
    4,4,4,4,4,4,8,4,4,4,4,4,4,4,8,4,
    8,12,12,16,12,16,8,16,8,16,12,8,12,24,8,16,
    8,12,12,0,12,16,8,16,8,16,12,0,12,0,8,16,
    12,12,8,0,0,16,8,16,16,4,16,0,0,0,8,16,
    12,12,8,4,0,16,8,16,12,8,16,4,0,0,8,16
  };
  return cyc[op];
}

U8 GBMemRead8(GBCpu *cpu, U16 addr)
{
  I64 bank;
  I64 off;
  I64 ramb;
  I64 banks;

  if (addr == 0xFF00)
    return GBJoyCompute(cpu);

  if (addr < 0x4000)
  {
    if (cpu->rom && cpu->rom_size > 0)
      return cpu->rom[addr % cpu->rom_size];
    return cpu->ram[addr];
  }
  if (addr < 0x8000)
  {
    bank = cpu->mbc_rom_bank;
    if (!bank)
      bank++;
    off = bank * 0x4000 + (addr - 0x4000);
    if (cpu->rom && cpu->rom_size > 0)
      return cpu->rom[off % cpu->rom_size];
    return cpu->ram[addr];
  }
  if (addr >= 0xA000 && addr < 0xC000)
  {
    if (cpu->ext_ram_size <= 0)
      return 0xFF;
    banks = GBExtRamBankCount(cpu);
    if (banks <= 0)
      return 0xFF;
    ramb = cpu->mbc_ram_bank % banks;
    return cpu->ext_ram[ramb * 0x2000 + (addr - 0xA000)];
  }
  return cpu->ram[addr];
}

U0 GBMemWrite8(GBCpu *cpu, U16 addr, U8 val)
{
  I64 ramb;
  I64 src;
  I64 banks;
  I64 off;

  if (addr < 0x2000)
  {
    if (cpu->cart_mbc == GB_CART_MBC1 || cpu->cart_mbc == GB_CART_MBC3)
      cpu->mbc_ram_enable = ((val & 0x0F) == 0x0A);
    return;
  }
  if (addr < 0x4000)
  {
    if (cpu->cart_mbc == GB_CART_MBC1)
    {
      cpu->mbc1_low5 = val & 0x1F;
      if (cpu->mbc1_low5 == 0)
        cpu->mbc1_low5 = 1;
      cpu->mbc_rom_bank = (cpu->mbc1_low5 | (cpu->mbc1_high2 << 5)) & 0x7F;
      if ((cpu->mbc_rom_bank & 0x1F) == 0)
        cpu->mbc_rom_bank++;
    }
    else if (cpu->cart_mbc == GB_CART_MBC3)
    {
      cpu->mbc_rom_bank = val & 0x7F;
      if (!cpu->mbc_rom_bank)
        cpu->mbc_rom_bank = 1;
    }
    return;
  }
  if (addr < 0x6000)
  {
    if (cpu->cart_mbc == GB_CART_MBC1)
    {
      cpu->mbc1_high2 = val & 0x03;
      cpu->mbc_rom_bank = (cpu->mbc1_low5 | (cpu->mbc1_high2 << 5)) & 0x7F;
      if ((cpu->mbc_rom_bank & 0x1F) == 0)
        cpu->mbc_rom_bank++;
    }
    else if (cpu->cart_mbc == GB_CART_MBC3)
      cpu->mbc_ram_bank = val & 0x03;
    return;
  }
  if (addr < 0x8000)
  {
    if (cpu->cart_mbc == GB_CART_MBC1)
      cpu->mbc1_mode = val & 1;
    return;
  }
  if (addr >= 0xA000 && addr < 0xC000)
  {
    if (cpu->ext_ram_size > 0)
    {
      banks = GBExtRamBankCount(cpu);
      if (banks > 0)
      {
        ramb = cpu->mbc_ram_bank % banks;
        off = ramb * 0x2000 + (addr - 0xA000);
        if (off < cpu->ext_ram_size)
        {
          if (cpu->ext_ram[off] != val)
          {
            cpu->ext_ram[off] = val;
            cpu->save_dirty = 1;
          }
        }
      }
    }
    return;
  }
  if (addr == GB_REG_DIV)
  {
    cpu->cycle_accum = 0;
    cpu->ram[GB_REG_DIV] = 0;
    return;
  }
  if (addr == 0xFF00)
  {
    cpu->ram[0xFF00] = 0xC0 | (val & 0x30) | 0x0F;
    cpu->joy_last_low = GBJoyCompute(cpu) & 0x0F;
    return;
  }
  if (addr == GB_REG_STAT)
  {
    cpu->ram[GB_REG_STAT] = 0x80 | (cpu->ram[GB_REG_STAT] & 0x07) | (val & 0x78);
    return;
  }
  if (addr == GB_REG_LY)
  {
    cpu->ram[GB_REG_LY] = 0;
    return;
  }
  if (addr == 0xFF46)
  {
    cpu->ram[addr] = val;
    src = (val & 0xFF) << 8;
    for (ramb = 0; ramb < 0xA0; ramb++)
      cpu->ram[0xFE00 + ramb] = GBMemRead8(cpu, (src + ramb) & 0xFFFF);
    return;
  }
  cpu->ram[addr] = val;
}

U8 GBFetch8(GBCpu *cpu)
{
  U8 v = GBMemRead8(cpu, cpu->pc);
  cpu->pc++;
  return v;
}

U16 GBFetch16(GBCpu *cpu)
{
  U16 lo = GBFetch8(cpu);
  U16 hi = GBFetch8(cpu);
  return lo | (hi << 8);
}

I64 GBSign8(U8 v)
{
  if (v & 0x80)
    return v - 0x100;
  return v;
}

U0 GBSetFlagZ(GBCpu *cpu, Bool set)
{
  if (set)
    cpu->f |= 0x80;
  else
    cpu->f &= ~0x80;
}

U0 GBSetFlagN(GBCpu *cpu, Bool set)
{
  if (set)
    cpu->f |= 0x40;
  else
    cpu->f &= ~0x40;
}

U0 GBSetFlagH(GBCpu *cpu, Bool set)
{
  if (set)
    cpu->f |= 0x20;
  else
    cpu->f &= ~0x20;
}

U0 GBSetFlagC(GBCpu *cpu, Bool set)
{
  if (set)
    cpu->f |= 0x10;
  else
    cpu->f &= ~0x10;
}

Bool GBGetFlagZ(GBCpu *cpu)
{
  return cpu->f & 0x80;
}

Bool GBGetFlagC(GBCpu *cpu)
{
  return cpu->f & 0x10;
}

U16 GBGetHL(GBCpu *cpu)
{
  return (cpu->h << 8) | cpu->l;
}

U0 GBSetHL(GBCpu *cpu, U16 v)
{
  cpu->h = v >> 8;
  cpu->l = v & 0xFF;
}

U8 GBReadR8(GBCpu *cpu, U8 idx)
{
  switch (idx)
  {
  case 0: return cpu->b;
  case 1: return cpu->c;
  case 2: return cpu->d;
  case 3: return cpu->e;
  case 4: return cpu->h;
  case 5: return cpu->l;
  case 6: return GBMemRead8(cpu, GBGetHL(cpu));
  case 7: return cpu->a;
  }
  return 0;
}

U0 GBWriteR8(GBCpu *cpu, U8 idx, U8 v)
{
  switch (idx)
  {
  case 0: cpu->b = v; return;
  case 1: cpu->c = v; return;
  case 2: cpu->d = v; return;
  case 3: cpu->e = v; return;
  case 4: cpu->h = v; return;
  case 5: cpu->l = v; return;
  case 6: GBMemWrite8(cpu, GBGetHL(cpu), v); return;
  case 7: cpu->a = v; return;
  }
}

U8 GBCbStep(GBCpu *cpu)
{
  U8 op = GBFetch8(cpu);
  U8 x = op >> 6;
  U8 y = (op >> 3) & 7;
  U8 z = op & 7;
  U8 v = GBReadR8(cpu, z);
  U8 c;
  U8 cin;

  if (x == 0)
  {
    switch (y)
    {
    case 0: // RLC
      c = (v >> 7) & 1;
      v = (v << 1) | c;
      break;
    case 1: // RRC
      c = v & 1;
      v = (v >> 1) | (c << 7);
      break;
    case 2: // RL
      c = (v >> 7) & 1;
      cin = 0;
      if (GBGetFlagC(cpu))
        cin = 1;
      v = (v << 1) | cin;
      break;
    case 3: // RR
      c = v & 1;
      cin = 0;
      if (GBGetFlagC(cpu))
        cin = 1;
      v = (v >> 1) | (cin << 7);
      break;
    case 4: // SLA
      c = (v >> 7) & 1;
      v = v << 1;
      break;
    case 5: // SRA
      c = v & 1;
      v = (v >> 1) | (v & 0x80);
      break;
    case 6: // SWAP
      c = 0;
      v = (v << 4) | (v >> 4);
      break;
    case 7: // SRL
      c = v & 1;
      v = v >> 1;
      break;
    }
    GBWriteR8(cpu, z, v);
    GBSetFlagZ(cpu, v == 0);
    GBSetFlagN(cpu, FALSE);
    GBSetFlagH(cpu, FALSE);
    GBSetFlagC(cpu, c);
    if (z == 6)
      return 16;
    return 8;
  }

  if (x == 1)
  {
    GBSetFlagZ(cpu, (v & (1 << y)) == 0);
    GBSetFlagN(cpu, FALSE);
    GBSetFlagH(cpu, TRUE);
    if (z == 6)
      return 12;
    return 8;
  }

  if (x == 2)
  {
    v &= ~(1 << y);
    GBWriteR8(cpu, z, v);
    if (z == 6)
      return 16;
    return 8;
  }

  v |= (1 << y);
  GBWriteR8(cpu, z, v);
  if (z == 6)
    return 16;
  return 8;
}

U0 GBOpCP(GBCpu *cpu, U8 val)
{
  U8 a = cpu->a;
  U8 r = a - val;
  GBSetFlagZ(cpu, r == 0);
  GBSetFlagN(cpu, TRUE);
  GBSetFlagH(cpu, (a & 0x0F) < (val & 0x0F));
  GBSetFlagC(cpu, a < val);
}

U0 GBOpADD(GBCpu *cpu, U8 val)
{
  U8 a = cpu->a;
  U16 sum = a + val;
  cpu->a = sum & 0xFF;
  GBSetFlagZ(cpu, cpu->a == 0);
  GBSetFlagN(cpu, FALSE);
  GBSetFlagH(cpu, ((a & 0x0F) + (val & 0x0F)) > 0x0F);
  GBSetFlagC(cpu, sum > 0xFF);
}

U0 GBOpADC(GBCpu *cpu, U8 val)
{
  U8 a = cpu->a;
  U8 c = 0;
  U16 sum;
  if (GBGetFlagC(cpu))
    c = 1;
  sum = a + val + c;
  cpu->a = sum & 0xFF;
  GBSetFlagZ(cpu, cpu->a == 0);
  GBSetFlagN(cpu, FALSE);
  GBSetFlagH(cpu, ((a & 0x0F) + (val & 0x0F) + c) > 0x0F);
  GBSetFlagC(cpu, sum > 0xFF);
}

U0 GBOpSUB(GBCpu *cpu, U8 val)
{
  U8 a = cpu->a;
  cpu->a = a - val;
  GBSetFlagZ(cpu, cpu->a == 0);
  GBSetFlagN(cpu, TRUE);
  GBSetFlagH(cpu, (a & 0x0F) < (val & 0x0F));
  GBSetFlagC(cpu, a < val);
}

U0 GBOpSBC(GBCpu *cpu, U8 val)
{
  U8 a = cpu->a;
  U8 c = 0;
  U16 sub;
  if (GBGetFlagC(cpu))
    c = 1;
  sub = a - val - c;
  cpu->a = sub & 0xFF;
  GBSetFlagZ(cpu, cpu->a == 0);
  GBSetFlagN(cpu, TRUE);
  GBSetFlagH(cpu, (a & 0x0F) < ((val & 0x0F) + c));
  GBSetFlagC(cpu, a < (val + c));
}

U0 GBOpAND(GBCpu *cpu, U8 val)
{
  cpu->a &= val;
  GBSetFlagZ(cpu, cpu->a == 0);
  GBSetFlagN(cpu, FALSE);
  GBSetFlagH(cpu, TRUE);
  GBSetFlagC(cpu, FALSE);
}

U0 GBOpOR(GBCpu *cpu, U8 val)
{
  cpu->a |= val;
  GBSetFlagZ(cpu, cpu->a == 0);
  GBSetFlagN(cpu, FALSE);
  GBSetFlagH(cpu, FALSE);
  GBSetFlagC(cpu, FALSE);
}

U0 GBOpXOR(GBCpu *cpu, U8 val)
{
  cpu->a ^= val;
  GBSetFlagZ(cpu, cpu->a == 0);
  GBSetFlagN(cpu, FALSE);
  GBSetFlagH(cpu, FALSE);
  GBSetFlagC(cpu, FALSE);
}

U0 GBOpINC8(GBCpu *cpu, U8 *r)
{
  U8 before = *r;
  *r = before + 1;
  GBSetFlagZ(cpu, *r == 0);
  GBSetFlagN(cpu, FALSE);
  GBSetFlagH(cpu, ((before & 0x0F) + 1) > 0x0F);
}

U0 GBOpDEC8(GBCpu *cpu, U8 *r)
{
  U8 before = *r;
  *r = before - 1;
  GBSetFlagZ(cpu, *r == 0);
  GBSetFlagN(cpu, TRUE);
  GBSetFlagH(cpu, (before & 0x0F) == 0);
}

U0 GBOpADDHL(GBCpu *cpu, U16 rhs)
{
  U16 hl;
  U32 sum;
  hl = GBGetHL(cpu);
  sum = hl + rhs;
  GBSetFlagN(cpu, FALSE);
  GBSetFlagH(cpu, ((hl & 0x0FFF) + (rhs & 0x0FFF)) > 0x0FFF);
  GBSetFlagC(cpu, sum > 0xFFFF);
  GBSetHL(cpu, sum & 0xFFFF);
}

U0 GBCpuInitFromRom(GBCpu *cpu, U8 *rom, I64 rom_size)
{
  I64 i;
  U8 ram_size_code;
  MemSet(cpu, 0, sizeof(GBCpu));
  cpu->rom = rom;
  cpu->rom_size = rom_size;
  cpu->cart_mbc = 0;
  cpu->mbc_rom_bank = 1;
  cpu->mbc_ram_bank = 0;
  cpu->mbc_ram_enable = 0;
  cpu->mbc1_low5 = 1;
  cpu->mbc1_high2 = 0;
  cpu->mbc1_mode = 0;
  cpu->joy_btn = 0x0F;
  cpu->joy_dpad = 0x0F;
  cpu->joy_last_low = 0x0F;
  cpu->save_dirty = 0;
  cpu->ext_ram_size = 0;
  MemSet(cpu->ext_ram, 0xFF, GB_EXT_RAM_CAP);
  if (rom_size > 0x147)
    cpu->cart_type = rom[0x147];
  if (rom_size > 0x149)
  {
    ram_size_code = rom[0x149];
    cpu->ext_ram_size = GBCartRamSize(ram_size_code);
    if (cpu->ext_ram_size > GB_EXT_RAM_CAP)
      cpu->ext_ram_size = GB_EXT_RAM_CAP;
  }
  if (cpu->cart_type == 0x01 || cpu->cart_type == 0x02 || cpu->cart_type == 0x03)
    cpu->cart_mbc = GB_CART_MBC1;
  else if (cpu->cart_type == 0x0F || cpu->cart_type == 0x10 ||
           cpu->cart_type == 0x11 || cpu->cart_type == 0x12 ||
           cpu->cart_type == 0x13)
    cpu->cart_mbc = GB_CART_MBC3;
  for (i = 0; i < rom_size && i < 0x8000; i++)
    cpu->ram[i] = rom[i];
  // Typical DMG state after boot ROM hands control to cartridge at 0x0100.
  cpu->a = 0x01;
  cpu->f = 0xB0;
  cpu->b = 0x00;
  cpu->c = 0x13;
  cpu->d = 0x00;
  cpu->e = 0xD8;
  cpu->h = 0x01;
  cpu->l = 0x4D;
  cpu->pc = 0x0100;
  cpu->sp = 0xFFFE;
  cpu->unsupported_pc = 0xFFFF;
  cpu->ime = 0;
  cpu->ime_delay = 0;
  cpu->halted = 0;
  cpu->stat_lyc_prev = 0;
  cpu->cycle_accum = 0;
  cpu->ly_accum = 0;
  cpu->tima_accum = 0;

  // Key IO defaults used by commercial DMG software.
  cpu->ram[0xFF05] = 0x00; // TIMA
  cpu->ram[0xFF06] = 0x00; // TMA
  cpu->ram[0xFF07] = 0x00; // TAC
  cpu->ram[0xFF10] = 0x80;
  cpu->ram[0xFF11] = 0xBF;
  cpu->ram[0xFF12] = 0xF3;
  cpu->ram[0xFF14] = 0xBF;
  cpu->ram[0xFF16] = 0x3F;
  cpu->ram[0xFF17] = 0x00;
  cpu->ram[0xFF19] = 0xBF;
  cpu->ram[0xFF1A] = 0x7F;
  cpu->ram[0xFF1B] = 0xFF;
  cpu->ram[0xFF1C] = 0x9F;
  cpu->ram[0xFF1E] = 0xBF;
  cpu->ram[0xFF20] = 0xFF;
  cpu->ram[0xFF21] = 0x00;
  cpu->ram[0xFF22] = 0x00;
  cpu->ram[0xFF23] = 0xBF;
  cpu->ram[0xFF24] = 0x77;
  cpu->ram[0xFF25] = 0xF3;
  cpu->ram[0xFF26] = 0xF1;
  cpu->ram[0xFF40] = 0x91; // LCDC
  cpu->ram[0xFF41] = 0x85; // STAT
  cpu->ram[0xFF42] = 0x00; // SCY
  cpu->ram[0xFF43] = 0x00; // SCX
  cpu->ram[0xFF44] = 0x00; // LY
  cpu->ram[0xFF45] = 0x00; // LYC
  cpu->ram[0xFF47] = 0xFC; // BGP
  cpu->ram[0xFF48] = 0xFF; // OBP0
  cpu->ram[0xFF49] = 0xFF; // OBP1
  cpu->ram[0xFF4A] = 0x00; // WY
  cpu->ram[0xFF4B] = 0x00; // WX
  cpu->ram[0xFF00] = 0xCF;
  cpu->ram[GB_REG_IF] = 0xE1;
  cpu->ram[GB_REG_DIV] = 0xAB;
  cpu->ram[GB_REG_IE] = 0x00;
  GBCpuLoadSave(cpu);
}

U0 GBUpdateStat(GBCpu *cpu)
{
  U8 stat;
  U8 ly;
  U8 lyc;
  U8 mode;
  U8 old_mode;
  U8 lyc_now;

  stat = cpu->ram[GB_REG_STAT];
  ly = cpu->ram[GB_REG_LY];
  lyc = cpu->ram[0xFF45];
  old_mode = stat & 3;

  if (ly >= 144)
    mode = 1;
  else if (cpu->ly_accum < 80)
    mode = 2;
  else if (cpu->ly_accum < 252)
    mode = 3;
  else
    mode = 0;

  lyc_now = (ly == lyc);

  stat &= 0xF8;
  stat |= mode;
  if (lyc_now)
    stat |= 0x04;
  else
    stat &= ~0x04;
  stat |= 0x80;
  cpu->ram[GB_REG_STAT] = stat;

  if (mode != old_mode)
  {
    if (mode == 0 && (stat & 0x08))
    {
      cpu->ram[GB_REG_IF] |= 0x02;
      cpu->irq_stat_raised++;
    }
    else if (mode == 1 && (stat & 0x10))
    {
      cpu->ram[GB_REG_IF] |= 0x02;
      cpu->irq_stat_raised++;
    }
    else if (mode == 2 && (stat & 0x20))
    {
      cpu->ram[GB_REG_IF] |= 0x02;
      cpu->irq_stat_raised++;
    }
  }
  if (lyc_now && !cpu->stat_lyc_prev && (stat & 0x40))
  {
    cpu->ram[GB_REG_IF] |= 0x02;
    cpu->irq_stat_raised++;
  }
  cpu->stat_lyc_prev = lyc_now;
}

U0 GBTick(GBCpu *cpu, I64 cycles)
{
  U8 ly;
  U8 tac;
  U8 tima;
  U8 tma;
  I64 step_cycles;

  cpu->cycle_accum += cycles;
  cpu->ram[GB_REG_DIV] = (cpu->cycle_accum >> 8) & 0xFF;

  if (GB_STRICT_LCD_OFF && !(cpu->ram[GB_REG_LCDC] & 0x80))
  {
    cpu->ly_accum = 0;
    cpu->ram[GB_REG_LY] = 0;
    GBUpdateStat(cpu);
    return;
  }

  cpu->ly_accum += cycles;
  while (cpu->ly_accum >= 456)
  {
    cpu->ly_accum -= 456;
    ly = cpu->ram[GB_REG_LY] + 1;
    if (ly >= 154)
      ly = 0;
    cpu->ram[GB_REG_LY] = ly;

    if (ly == 144)
    {
      cpu->ram[GB_REG_IF] |= 0x01;
      cpu->irq_vblank_raised++;
    }
  }

  GBUpdateStat(cpu);

  tac = cpu->ram[0xFF07];
  if (tac & 0x04)
  {
    if ((tac & 0x03) == 0)
      step_cycles = 1024;
    else if ((tac & 0x03) == 1)
      step_cycles = 16;
    else if ((tac & 0x03) == 2)
      step_cycles = 64;
    else
      step_cycles = 256;

    cpu->tima_accum += cycles;
    while (cpu->tima_accum >= step_cycles)
    {
      cpu->tima_accum -= step_cycles;
      tima = cpu->ram[0xFF05];
      tma = cpu->ram[0xFF06];
      if (tima == 0xFF)
      {
        cpu->ram[0xFF05] = tma;
        cpu->ram[GB_REG_IF] |= 0x04;
        cpu->irq_timer_raised++;
      }
      else
        cpu->ram[0xFF05] = tima + 1;
    }
  }
}

Bool GBServiceInterrupts(GBCpu *cpu)
{
  U8 ie;
  U8 iflags;
  U8 pending;
  U8 bit;
  U16 vec[5];
  ie = cpu->ram[GB_REG_IE];
  iflags = cpu->ram[GB_REG_IF];
  pending = ie & iflags & 0x1F;
  vec[0] = 0x40;
  vec[1] = 0x48;
  vec[2] = 0x50;
  vec[3] = 0x58;
  vec[4] = 0x60;

  if (!pending)
    return FALSE;

  if (cpu->halted)
    cpu->halted = FALSE;
  if (!cpu->ime)
    return FALSE;

  cpu->ime = 0;
  for (bit = 0; bit < 5; bit++)
  {
    if (pending & (1 << bit))
    {
      cpu->ram[GB_REG_IF] &= ~(1 << bit);
      if (bit == 0)
        cpu->irq_vblank_served++;
      else if (bit == 1)
        cpu->irq_stat_served++;
      else if (bit == 2)
        cpu->irq_timer_served++;
      else if (bit == 3)
        cpu->irq_serial_served++;
      else if (bit == 4)
        cpu->irq_joy_served++;
      cpu->sp--;
      GBMemWrite8(cpu, cpu->sp, cpu->pc >> 8);
      cpu->sp--;
      GBMemWrite8(cpu, cpu->sp, cpu->pc & 0xFF);
      cpu->last_pc = cpu->pc;
      cpu->last_op = 0xFF;
      cpu->pc = vec[bit];
      return TRUE;
    }
  }
  return FALSE;
}

U0 GBCpuStep(GBCpu *cpu)
{
  U16 op_pc;
  U8 op;
  I64 cycles;
  I64 cycle_extra;
  I64 rel;
  U16 nn;
  U16 hl;
  U16 bc;
  U16 de;
  U8 rhs;
  U8 g;

  if (cpu->ime_delay)
  {
    cpu->ime_delay--;
    if (!cpu->ime_delay)
      cpu->ime = 1;
  }

  if (GBServiceInterrupts(cpu))
  {
    GBTick(cpu, 20);
    return;
  }

  if (cpu->halted)
  {
    GBTick(cpu, 4);
    return;
  }

  op_pc = cpu->pc;
  op = GBFetch8(cpu);
  cycles = GBBaseCycles(op);
  cycle_extra = 0;
  if (op_pc == 0x20b4)
  {
    cpu->pc_loop_hits++;
    if (!cpu->ram[0xFFD6])
      cpu->pc_loop_zero_hits++;
  }
  if (op_pc == 0x0040)
    cpu->pc_vblank_entry_hits++;
  cpu->last_pc = op_pc;
  cpu->last_op = op;

  // LD r,r' block (+HALT at 0x76).
  if (op >= 0x40 && op <= 0x7F)
  {
    if (op == 0x76)
    {
      cpu->halted = TRUE;
      GBTick(cpu, 4);
      return;
    }
    GBWriteR8(cpu, (op >> 3) & 7, GBReadR8(cpu, op & 7));
    if (!cycles)
      cycles = 4;
    GBTick(cpu, cycles);
    return;
  }

  // ALU A,r block.
  if (op >= 0x80 && op <= 0xBF)
  {
    cpu->alu_block_hits++;
    if (op == 0x9D)
      cpu->op_9d_hits++;
    rhs = GBReadR8(cpu, op & 7);
    g = (op >> 3) & 7;
    switch (g)
    {
    case 0: GBOpADD(cpu, rhs); if (!cycles) cycles = 4; GBTick(cpu, cycles); return; // ADD A,r
    case 1: GBOpADC(cpu, rhs); if (!cycles) cycles = 4; GBTick(cpu, cycles); return; // ADC A,r
    case 2: GBOpSUB(cpu, rhs); if (!cycles) cycles = 4; GBTick(cpu, cycles); return; // SUB A,r
    case 3: GBOpSBC(cpu, rhs); if (!cycles) cycles = 4; GBTick(cpu, cycles); return; // SBC A,r
    case 4: GBOpAND(cpu, rhs); if (!cycles) cycles = 4; GBTick(cpu, cycles); return; // AND A,r
    case 5: GBOpXOR(cpu, rhs); if (!cycles) cycles = 4; GBTick(cpu, cycles); return; // XOR A,r
    case 6: GBOpOR(cpu, rhs);  if (!cycles) cycles = 4; GBTick(cpu, cycles); return; // OR A,r
    case 7: GBOpCP(cpu, rhs);  if (!cycles) cycles = 4; GBTick(cpu, cycles); return; // CP A,r
    }
  }

  // LR35902 undefined opcodes: treat as NOP during bring-up.
  // Put this before switch() to avoid parser/dispatch edge cases.
  if (op == 0xD3 || op == 0xDB || op == 0xDD ||
      op == 0xE3 || op == 0xE4 || op == 0xEB || op == 0xEC || op == 0xED ||
      op == 0xF4 || op == 0xFC || op == 0xFD)
  {
    if (!cycles)
      cycles = 4;
    GBTick(cpu, cycles);
    return;
  }

  switch (op)
  {
  case 0x00: // NOP
    break;
  case 0x01: // LD BC,d16
    nn = GBFetch16(cpu);
    cpu->b = nn >> 8;
    cpu->c = nn & 0xFF;
    break;
  case 0x02: // LD (BC),A
    bc = (cpu->b << 8) | cpu->c;
    GBMemWrite8(cpu, bc, cpu->a);
    break;
  case 0x03: // INC BC
    bc = (cpu->b << 8) | cpu->c;
    bc++;
    cpu->b = bc >> 8;
    cpu->c = bc & 0xFF;
    break;
  case 0x04: // INC B
    cpu->b++;
    GBSetFlagZ(cpu, cpu->b == 0);
    GBSetFlagN(cpu, FALSE);
    break;
  case 0x05: // DEC B
    cpu->b--;
    GBSetFlagZ(cpu, cpu->b == 0);
    GBSetFlagN(cpu, TRUE);
    break;
  case 0x06: // LD B,d8
    cpu->b = GBFetch8(cpu);
    break;
  case 0x07: // RLCA
    nn = (cpu->a >> 7) & 1;
    cpu->a = (cpu->a << 1) | nn;
    GBSetFlagZ(cpu, FALSE);
    GBSetFlagN(cpu, FALSE);
    GBSetFlagH(cpu, FALSE);
    GBSetFlagC(cpu, nn);
    break;
  case 0x08: // LD (a16),SP
    nn = GBFetch16(cpu);
    GBMemWrite8(cpu, nn, cpu->sp & 0xFF);
    GBMemWrite8(cpu, nn + 1, cpu->sp >> 8);
    break;
  case 0x09: // ADD HL,BC
    bc = (cpu->b << 8) | cpu->c;
    GBOpADDHL(cpu, bc);
    break;
  case 0x0A: // LD A,(BC)
    bc = (cpu->b << 8) | cpu->c;
    cpu->a = GBMemRead8(cpu, bc);
    break;
  case 0x19: // ADD HL,DE
    de = (cpu->d << 8) | cpu->e;
    GBOpADDHL(cpu, de);
    break;
  case 0x0B: // DEC BC
    bc = (cpu->b << 8) | cpu->c;
    bc--;
    cpu->b = bc >> 8;
    cpu->c = bc & 0xFF;
    break;
  case 0x0C: // INC C
    GBOpINC8(cpu, &cpu->c);
    break;
  case 0x0D: // DEC C
    GBOpDEC8(cpu, &cpu->c);
    break;
  case 0x0E: // LD C,d8
    cpu->c = GBFetch8(cpu);
    break;
  case 0x0F: // RRCA
    nn = cpu->a & 1;
    cpu->a = (cpu->a >> 1) | (nn << 7);
    GBSetFlagZ(cpu, FALSE);
    GBSetFlagN(cpu, FALSE);
    GBSetFlagH(cpu, FALSE);
    GBSetFlagC(cpu, nn);
    break;
  case 0x10: // STOP
    cpu->halted = TRUE;
    break;
  case 0x11: // LD DE,d16
    nn = GBFetch16(cpu);
    cpu->d = nn >> 8;
    cpu->e = nn & 0xFF;
    break;
  case 0x12: // LD (DE),A
    nn = (cpu->d << 8) | cpu->e;
    GBMemWrite8(cpu, nn, cpu->a);
    break;
  case 0x13: // INC DE
    nn = (cpu->d << 8) | cpu->e;
    nn++;
    cpu->d = nn >> 8;
    cpu->e = nn & 0xFF;
    break;
  case 0x14: // INC D
    GBOpINC8(cpu, &cpu->d);
    break;
  case 0x15: // DEC D
    GBOpDEC8(cpu, &cpu->d);
    break;
  case 0x16: // LD D,d8
    cpu->d = GBFetch8(cpu);
    break;
  case 0x17: // RLA
    nn = (cpu->a >> 7) & 1;
    de = 0;
    if (GBGetFlagC(cpu))
      de = 1;
    cpu->a = (cpu->a << 1) | de;
    GBSetFlagZ(cpu, FALSE);
    GBSetFlagN(cpu, FALSE);
    GBSetFlagH(cpu, FALSE);
    GBSetFlagC(cpu, nn);
    break;
  case 0x18: // JR r8
    rel = GBSign8(GBFetch8(cpu));
    cpu->pc += rel;
    break;
  case 0x1B: // DEC DE
    nn = (cpu->d << 8) | cpu->e;
    nn--;
    cpu->d = nn >> 8;
    cpu->e = nn & 0xFF;
    break;
  case 0x1E: // LD E,d8
    cpu->e = GBFetch8(cpu);
    break;
  case 0x1C: // INC E
    GBOpINC8(cpu, &cpu->e);
    break;
  case 0x1D: // DEC E
    GBOpDEC8(cpu, &cpu->e);
    break;
  case 0x22: // LD (HL+),A
    hl = GBGetHL(cpu);
    GBMemWrite8(cpu, hl, cpu->a);
    GBSetHL(cpu, hl + 1);
    break;
  case 0x23: // INC HL
    GBSetHL(cpu, GBGetHL(cpu) + 1);
    break;
  case 0x1A: // LD A,(DE)
    nn = (cpu->d << 8) | cpu->e;
    cpu->a = GBMemRead8(cpu, nn);
    break;
  case 0x20: // JR NZ,r8
    rel = GBSign8(GBFetch8(cpu));
    if (!GBGetFlagZ(cpu))
    {
      cpu->pc += rel;
      cycle_extra = 4;
    }
    break;
  case 0x21: // LD HL,d16
    GBSetHL(cpu, GBFetch16(cpu));
    break;
  case 0x28: // JR Z,r8
    rel = GBSign8(GBFetch8(cpu));
    if (GBGetFlagZ(cpu))
    {
      cpu->pc += rel;
      cycle_extra = 4;
    }
    break;
  case 0x30: // JR NC,r8
    rel = GBSign8(GBFetch8(cpu));
    if (!GBGetFlagC(cpu))
    {
      cpu->pc += rel;
      cycle_extra = 4;
    }
    break;
  case 0x2A: // LD A,(HL+)
    hl = GBGetHL(cpu);
    cpu->a = GBMemRead8(cpu, hl);
    GBSetHL(cpu, hl + 1);
    break;
  case 0x24: // INC H
    GBOpINC8(cpu, &cpu->h);
    break;
  case 0x25: // DEC H
    GBOpDEC8(cpu, &cpu->h);
    break;
  case 0x26: // LD H,d8
    cpu->h = GBFetch8(cpu);
    break;
  case 0x27: // DAA
    nn = 0;
    if (cpu->f & 0x40) // N
    {
      if (cpu->f & 0x20)
        nn |= 0x06;
      if (cpu->f & 0x10)
        nn |= 0x60;
      cpu->a -= nn;
    }
    else
    {
      if ((cpu->f & 0x20) || (cpu->a & 0x0F) > 9)
        nn |= 0x06;
      if ((cpu->f & 0x10) || cpu->a > 0x99)
      {
        nn |= 0x60;
        GBSetFlagC(cpu, TRUE);
      }
      cpu->a += nn;
    }
    GBSetFlagZ(cpu, cpu->a == 0);
    GBSetFlagH(cpu, FALSE);
    break;
  case 0x29: // ADD HL,HL
    GBOpADDHL(cpu, GBGetHL(cpu));
    break;
  case 0x2B: // DEC HL
    GBSetHL(cpu, GBGetHL(cpu) - 1);
    break;
  case 0x2C: // INC L
    GBOpINC8(cpu, &cpu->l);
    break;
  case 0x2D: // DEC L
    GBOpDEC8(cpu, &cpu->l);
    break;
  case 0x2E: // LD L,d8
    cpu->l = GBFetch8(cpu);
    break;
  case 0x2F: // CPL
    cpu->a ^= 0xFF;
    GBSetFlagN(cpu, TRUE);
    GBSetFlagH(cpu, TRUE);
    break;
  case 0x31: // LD SP,d16
    cpu->sp = GBFetch16(cpu);
    break;
  case 0x33: // INC SP
    cpu->sp++;
    break;
  case 0x34: // INC (HL)
    hl = GBGetHL(cpu);
    nn = GBMemRead8(cpu, hl);
    nn = (nn + 1) & 0xFF;
    GBMemWrite8(cpu, hl, nn);
    GBSetFlagZ(cpu, nn == 0);
    GBSetFlagN(cpu, FALSE);
    GBSetFlagH(cpu, (nn & 0x0F) == 0);
    break;
  case 0x35: // DEC (HL)
    hl = GBGetHL(cpu);
    nn = GBMemRead8(cpu, hl);
    GBSetFlagH(cpu, (nn & 0x0F) == 0);
    nn = (nn - 1) & 0xFF;
    GBMemWrite8(cpu, hl, nn);
    GBSetFlagZ(cpu, nn == 0);
    GBSetFlagN(cpu, TRUE);
    break;
  case 0x36: // LD (HL),d8
    GBMemWrite8(cpu, GBGetHL(cpu), GBFetch8(cpu));
    break;
  case 0x37: // SCF
    GBSetFlagN(cpu, FALSE);
    GBSetFlagH(cpu, FALSE);
    GBSetFlagC(cpu, TRUE);
    break;
  case 0x3F: // CCF
    GBSetFlagN(cpu, FALSE);
    GBSetFlagH(cpu, FALSE);
    GBSetFlagC(cpu, !GBGetFlagC(cpu));
    break;
  case 0x38: // JR C,r8
    rel = GBSign8(GBFetch8(cpu));
    if (GBGetFlagC(cpu))
    {
      cpu->pc += rel;
      cycle_extra = 4;
    }
    break;
  case 0x39: // ADD HL,SP
    GBOpADDHL(cpu, cpu->sp);
    break;
  case 0x3A: // LD A,(HL-)
    hl = GBGetHL(cpu);
    cpu->a = GBMemRead8(cpu, hl);
    GBSetHL(cpu, hl - 1);
    break;
  case 0x3B: // DEC SP
    cpu->sp--;
    break;
  case 0x32: // LD (HL-),A
    hl = GBGetHL(cpu);
    GBMemWrite8(cpu, hl, cpu->a);
    GBSetHL(cpu, hl - 1);
    break;
  case 0x3D: // DEC A
    GBOpDEC8(cpu, &cpu->a);
    break;
  case 0x3C: // INC A
    GBOpINC8(cpu, &cpu->a);
    break;
  case 0x3E: // LD A,d8
    cpu->a = GBFetch8(cpu);
    break;
  case 0x47: // LD B,A
    cpu->b = cpu->a;
    break;
  case 0x4F: // LD C,A
    cpu->c = cpu->a;
    break;
  case 0x57: // LD D,A
    cpu->d = cpu->a;
    break;
  case 0x5F: // LD E,A
    cpu->e = cpu->a;
    break;
  case 0x67: // LD H,A
    cpu->h = cpu->a;
    break;
  case 0x6F: // LD L,A
    cpu->l = cpu->a;
    break;
  case 0x77: // LD (HL),A
    GBMemWrite8(cpu, GBGetHL(cpu), cpu->a);
    break;
  case 0xAF: // XOR A
    cpu->a = 0;
    cpu->f = 0x80;
    break;
  case 0xB7: // OR A
    GBOpOR(cpu, cpu->a);
    break;
  case 0x9D: // SBC A,L (fallback if ALU block path is bypassed)
    GBOpSBC(cpu, cpu->l);
    break;
  case 0xC1: // POP BC
    cpu->c = GBMemRead8(cpu, cpu->sp);
    cpu->sp++;
    cpu->b = GBMemRead8(cpu, cpu->sp);
    cpu->sp++;
    break;
  case 0xCB: // PREFIX CB
    GBTick(cpu, GBCbStep(cpu));
    return;
  case 0xD1: // POP DE
    cpu->e = GBMemRead8(cpu, cpu->sp);
    cpu->sp++;
    cpu->d = GBMemRead8(cpu, cpu->sp);
    cpu->sp++;
    break;
  case 0xD5: // PUSH DE
    cpu->sp--;
    GBMemWrite8(cpu, cpu->sp, cpu->d);
    cpu->sp--;
    GBMemWrite8(cpu, cpu->sp, cpu->e);
    break;
  case 0xC3: // JP a16
    cpu->pc = GBFetch16(cpu);
    break;
  case 0xC2: // JP NZ,a16
    nn = GBFetch16(cpu);
    if (!GBGetFlagZ(cpu))
    {
      cpu->pc = nn;
      cycle_extra = 4;
    }
    break;
  case 0xC0: // RET NZ
    if (!GBGetFlagZ(cpu))
    {
      nn = GBMemRead8(cpu, cpu->sp);
      cpu->sp++;
      nn |= GBMemRead8(cpu, cpu->sp) << 8;
      cpu->sp++;
      cpu->pc = nn;
      cycle_extra = 12;
    }
    break;
  case 0xC5: // PUSH BC
    cpu->sp--;
    GBMemWrite8(cpu, cpu->sp, cpu->b);
    cpu->sp--;
    GBMemWrite8(cpu, cpu->sp, cpu->c);
    break;
  case 0xC6: // ADD A,d8
    GBOpADD(cpu, GBFetch8(cpu));
    break;
  case 0xC8: // RET Z
    if (GBGetFlagZ(cpu))
    {
      nn = GBMemRead8(cpu, cpu->sp);
      cpu->sp++;
      nn |= GBMemRead8(cpu, cpu->sp) << 8;
      cpu->sp++;
      cpu->pc = nn;
      cycle_extra = 12;
    }
    break;
  case 0xC9: // RET
    nn = GBMemRead8(cpu, cpu->sp);
    cpu->sp++;
    nn |= GBMemRead8(cpu, cpu->sp) << 8;
    cpu->sp++;
    cpu->pc = nn;
    break;
  case 0xCD: // CALL a16
    nn = GBFetch16(cpu);
    cpu->sp--;
    GBMemWrite8(cpu, cpu->sp, cpu->pc >> 8);
    cpu->sp--;
    GBMemWrite8(cpu, cpu->sp, cpu->pc & 0xFF);
    cpu->pc = nn;
    break;
  case 0xC4: // CALL NZ,a16
    nn = GBFetch16(cpu);
    if (!GBGetFlagZ(cpu))
    {
      cpu->sp--;
      GBMemWrite8(cpu, cpu->sp, cpu->pc >> 8);
      cpu->sp--;
      GBMemWrite8(cpu, cpu->sp, cpu->pc & 0xFF);
      cpu->pc = nn;
      cycle_extra = 12;
    }
    break;
  case 0xCC: // CALL Z,a16
    nn = GBFetch16(cpu);
    if (GBGetFlagZ(cpu))
    {
      cpu->sp--;
      GBMemWrite8(cpu, cpu->sp, cpu->pc >> 8);
      cpu->sp--;
      GBMemWrite8(cpu, cpu->sp, cpu->pc & 0xFF);
      cpu->pc = nn;
      cycle_extra = 12;
    }
    break;
  case 0xCA: // JP Z,a16
    nn = GBFetch16(cpu);
    if (GBGetFlagZ(cpu))
    {
      cpu->pc = nn;
      cycle_extra = 4;
    }
    break;
  case 0xD0: // RET NC
    if (!GBGetFlagC(cpu))
    {
      nn = GBMemRead8(cpu, cpu->sp);
      cpu->sp++;
      nn |= GBMemRead8(cpu, cpu->sp) << 8;
      cpu->sp++;
      cpu->pc = nn;
      cycle_extra = 12;
    }
    break;
  case 0xD2: // JP NC,a16
    nn = GBFetch16(cpu);
    if (!GBGetFlagC(cpu))
    {
      cpu->pc = nn;
      cycle_extra = 4;
    }
    break;
  case 0xD6: // SUB d8
    GBOpSUB(cpu, GBFetch8(cpu));
    break;
  case 0xD4: // CALL NC,a16
    nn = GBFetch16(cpu);
    if (!GBGetFlagC(cpu))
    {
      cpu->sp--;
      GBMemWrite8(cpu, cpu->sp, cpu->pc >> 8);
      cpu->sp--;
      GBMemWrite8(cpu, cpu->sp, cpu->pc & 0xFF);
      cpu->pc = nn;
      cycle_extra = 12;
    }
    break;
  case 0xDC: // CALL C,a16
    nn = GBFetch16(cpu);
    if (GBGetFlagC(cpu))
    {
      cpu->sp--;
      GBMemWrite8(cpu, cpu->sp, cpu->pc >> 8);
      cpu->sp--;
      GBMemWrite8(cpu, cpu->sp, cpu->pc & 0xFF);
      cpu->pc = nn;
      cycle_extra = 12;
    }
    break;
  case 0xE0: // LDH (a8),A
    GBMemWrite8(cpu, 0xFF00 | GBFetch8(cpu), cpu->a);
    break;
  case 0xE1: // POP HL
    cpu->l = GBMemRead8(cpu, cpu->sp);
    cpu->sp++;
    cpu->h = GBMemRead8(cpu, cpu->sp);
    cpu->sp++;
    break;
  case 0xE2: // LD (C),A
    GBMemWrite8(cpu, 0xFF00 | cpu->c, cpu->a);
    break;
  case 0xE5: // PUSH HL
    cpu->sp--;
    GBMemWrite8(cpu, cpu->sp, cpu->h);
    cpu->sp--;
    GBMemWrite8(cpu, cpu->sp, cpu->l);
    break;
  case 0xE6: // AND d8
    GBOpAND(cpu, GBFetch8(cpu));
    break;
  case 0xE9: // JP (HL)
    cpu->pc = GBGetHL(cpu);
    break;
  case 0xE3: // Undefined on LR35902; treat as NOP for bring-up
    break;
  case 0xE4: // Undefined on LR35902; treat as NOP for bring-up
    break;
  case 0xEB: // Undefined on LR35902; treat as NOP for bring-up
    break;
  case 0xEC: // Undefined on LR35902; treat as NOP for bring-up
    break;
  case 0xED: // Undefined on LR35902; treat as NOP for bring-up
    break;
  case 0xEA: // LD (a16),A
    GBMemWrite8(cpu, GBFetch16(cpu), cpu->a);
    break;
  case 0xEE: // XOR d8
    GBOpXOR(cpu, GBFetch8(cpu));
    break;
  case 0xD8: // RET C
    if (GBGetFlagC(cpu))
    {
      nn = GBMemRead8(cpu, cpu->sp);
      cpu->sp++;
      nn |= GBMemRead8(cpu, cpu->sp) << 8;
      cpu->sp++;
      cpu->pc = nn;
      cycle_extra = 12;
    }
    break;
  case 0xD9: // RETI
    nn = GBMemRead8(cpu, cpu->sp);
    cpu->sp++;
    nn |= GBMemRead8(cpu, cpu->sp) << 8;
    cpu->sp++;
    cpu->pc = nn;
    cpu->ime = 1;
    cpu->ime_delay = 0;
    break;
  case 0xDA: // JP C,a16
    nn = GBFetch16(cpu);
    if (GBGetFlagC(cpu))
    {
      cpu->pc = nn;
      cycle_extra = 4;
    }
    break;
  case 0xF0: // LDH A,(a8)
    cpu->a = GBMemRead8(cpu, 0xFF00 | GBFetch8(cpu));
    break;
  case 0xF1: // POP AF
    cpu->f = GBMemRead8(cpu, cpu->sp) & 0xF0;
    cpu->sp++;
    cpu->a = GBMemRead8(cpu, cpu->sp);
    cpu->sp++;
    break;
  case 0xF3: // DI
    cpu->ime = 0;
    cpu->ime_delay = 0;
    break;
  case 0xF4: // Undefined on LR35902; treat as NOP for bring-up
    break;
  case 0xF5: // PUSH AF
    cpu->sp--;
    GBMemWrite8(cpu, cpu->sp, cpu->a);
    cpu->sp--;
    GBMemWrite8(cpu, cpu->sp, cpu->f & 0xF0);
    break;
  case 0xF6: // OR d8
    GBOpOR(cpu, GBFetch8(cpu));
    break;
  case 0xF8: // LD HL,SP+r8
    rel = GBSign8(GBFetch8(cpu));
    nn = cpu->sp + rel;
    GBSetFlagZ(cpu, FALSE);
    GBSetFlagN(cpu, FALSE);
    // Use canonical xor-based carry detection for signed add to SP.
    de = cpu->sp ^ rel ^ nn;
    GBSetFlagH(cpu, (de & 0x10) != 0);
    GBSetFlagC(cpu, (de & 0x100) != 0);
    GBSetHL(cpu, nn);
    break;
  case 0xF9: // LD SP,HL
    cpu->sp = GBGetHL(cpu);
    break;
  case 0xFA: // LD A,(a16)
    cpu->a = GBMemRead8(cpu, GBFetch16(cpu));
    break;
  case 0xFE: // CP d8
    GBOpCP(cpu, GBFetch8(cpu));
    break;
  case 0xFB: // EI
    cpu->ime_delay = 2;
    break;
  case 0xD3: // Undefined on LR35902; treat as NOP for bring-up
    break;
  case 0xDB: // Undefined on LR35902; treat as NOP for bring-up
    break;
  case 0xDD: // Undefined on LR35902; treat as NOP for bring-up
    break;
  case 0xFC: // Undefined on LR35902; treat as NOP for bring-up
    break;
  case 0xFD: // Undefined on LR35902; treat as NOP for bring-up
    break;
  default:
    cpu->unsupported = op;
    cpu->unsupported_pc = op_pc;
    break;
  }

  if (!cycles)
    cycles = 4;
  GBTick(cpu, cycles + cycle_extra);
}
