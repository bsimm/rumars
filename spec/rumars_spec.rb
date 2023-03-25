# frozen_string_literal: true

require_relative '../lib/rumars/mars'

RSpec.describe RuMARS::MARS do
  it 'should execute the Imp program' do
    mars = RuMARS::MARS.new
    warrior = RuMARS::Warrior.new('Imp')
    prg = <<~"PRG"
      ;redcode-94
            mov +0, +1
            end
    PRG
    warrior.parse(prg)
    mars.add_warrior(warrior)
    mars.run(80)
    expect(mars.cycles).to eql(80)
  end

  it 'should execute the Dwarf program' do
    prg = <<~"PRG"
      ;redcode-94
            org start
            DAT.F   #0,   #0
      start ADD.AB  #4,   $-1
            MOV.AB  #0,   @-2
            JMP.A   $-2,  #0
            end
    PRG

    mars = RuMARS::MARS.new
    warrior = RuMARS::Warrior.new('Imp')
    warrior.parse(prg)
    mars.add_warrior(warrior)
    mars.run(4)
    expect(mars.cycles).to eql(4)
  end

  it 'should properly support in-register evaluation' do
    prg = <<~"PRG"
      ;redcode-94
            org     start
      val   dat.f   #0,    #1
      start mov     val,   <val
            sub.ab  #1,    val
            jmn.a   error, val
            jmn.b   error, val
      loop  jmp.a   loop
      error dat.f   #0,   #0
            end
    PRG

    mars = RuMARS::MARS.new
    warrior = RuMARS::Warrior.new('Imp')
    warrior.parse(prg)
    mars.add_warrior(warrior)
    mars.run(10)
    expect(mars.cycles).to eql(10)
  end

  it 'should use the addressing modes correctly' do
    prg = <<~"PRG"
      ;redcode-94
            org start
      ; Test direct addressing mode for A value
      var1  dat.f   #5,    #7
      var2  dat.f   #7,    #5
      var3  dat.f   #5,    #7
      var4  dat.f   var3,  $0
      var5  dat.f   #7,    #5
      var6  dat.f   $0,    var5
      var7  dat.f   #5,    #7
      var8  dat.f   $0,    $7
      var9  dat.f   #5,    #7
      var10 dat.f   $7,    $0
      var11 dat.f   #5,    #7
      var12 dat.f   var11, $7
      var13 dat.f   #5,    #7
      var14 dat.f   $0,    var13

      start sub.a   #5,    var1
            jmn.a   error, var1
      ; Test direct addressing mode for B value
            sub.ab  #5,    var2
            jmn.b   error, var2
      ; Test indirect addressing mode for A value
            sub.a   #5,    *var4
            jmn.a   error, var3
      ; Test indirect addressing mode for B value
            sub.ab  #5,    @var6
            jmn.b   error, var5
      ; Test predecrement indirect addressing mode for A value
            sub.a   #5,    {var8
            jmn.a   error, var7
      ; Test predecrement indirect addressing mode for B value
            sub.a   #5,    <var10
            jmn.a   error, var9
      ; Test post-increment indirect addressing mode for A value
            sub.a   #5,    }var12
            jmn.a   error, var11
            jmn.a   error, var12
      ; Test post-increment indirect addressing mode for B value
            sub.a   #5,    >var14
            jmn.a   error, var13
            jmn.a   error, var14
      loop  jmp.a   loop
      error dat.f   #0,    #0
            end
    PRG

    mars = RuMARS::MARS.new
    warrior = RuMARS::Warrior.new('Imp')
    warrior.parse(prg)
    mars.add_warrior(warrior)
    mars.run(20)
    expect(mars.cycles).to eql(20)
  end

  it 'should be ICWS88-standard compliant' do
    prg = <<~"PRG"
      ;redcode
      ;name Validate 1.1R
      ;author Stefan Strack
      ;strategy System validation program - based on Mark Durham's validation suite
      ;
      ;   This program tests your corewar system for compliance with the ICWS88-
      ;   standard and compatibility with KotH. It self-ties (i.e. loops forever)
      ;   if the running system is ICWS88-compliant and uses in-register evaluation;
      ;   suicides (terminates) if the interpreter is not ICWS compliant and/or uses
      ;   in-memory evaluation. A counter at label 'flag' can be used to determine
      ;   where the exception occurred.
      ;
      ;   Tests:
      ;   -all opcodes and addressing modes
      ;   -ICWS88-style ADD/SUB
      ;   -ICWS88-style SPL
      ;   -correct timing
      ;   -in-memory vs. in-register evaluation
      ;   -core initialization
      ;
      ;   Version 1.1: added autodestruct in case process gets stuck


      ;assert MAXLENGTH >= 90

      start   spl l1,count+1
              jmz <start,0
      count   djn count,#36      ;time cycles
              sub #1,@start
      clear   mov t1,<last+2     ;autodestruct if stuck
              jmp clear
      t1      dat #0,#1
      t2      dat #0,#3
      l1      spl l2
              dat <t2,<t2
      l2      cmp t1,t2
              jmp fail
              spl l4
              jmz l3,<0
      t3      dat #0,#1
      t4      dat #0,#2
      l3      jmp @0,<0
      l4      jmp <t5,#0
              jmp l5
      t5      dat #0,#0
      t6      dat #0,#-1
      l5      cmp t3,t4
              jmp fail
              cmp t5,t6
              jmp fail
              jmp <t7,<t7
              jmp l6
      t7      dat #0,#0
      t8      dat #0,#-2
      l6      cmp t7,t8
              jmp fail
              mov t9,<t9         ;test in-memory evaluation
      t9      jmn l7,1
      t10     jmn l7+1,1
      l7      cmp t9,t10
              jmp fail
              mov @0,<t11
      t11     jmn l8,1
      t12     jmn l8+1,1
      l8      cmp t11,t12
              jmp fail
              spl l9
              mov <t13,t14
      t13     dat <0,#1
      t14     dat <0,#1
      t15     dat <0,#-1
      l9      mov <t16,t16
      t16     jmz l10,1
              jmp fail
      l10     cmp t13,t15
              jmp fail
              add t17,<t17
      t17     jmp 1,1
      t18     jmp 2,1
              cmp t17,t18
              jmp fail
              add @0,<t19
      t19     jmp 1,1
              jmp fail
              cmp t18,t19
              jmp fail
              spl l11            ;ICWS86 SPL will fail here
              cmp t20,t21
              jmp l12
              jmp fail
      l11     sub <t20,t20
      t20     dat #2,#1
      t21     dat #0,#0
      l12     cmp t20,t21
              jmp fail
      t22     sub <t23,<t23
      t23     jmp l13,1
      t24     sub <-2,<1
      t25     jmp l13+2,-1
      l13     cmp t22,t24
              jmp fail
              cmp t23,t25
              jmp fail
              cmp start-1,t26    ;Core initialization dat 0,0
              jmp l14
              jmp fail
      t26     dat #0,#0
      l14     slt #0,count       ;check cycle timer
              jmp success
      fail    mov count,flag     ;save counter for post-mortem debugging
              mov t1,count       ;kill counter
              jmp clear          ;and auto-destruct
      flag    dat #0, #0
      success mov flag,clear     ;cancel autodestruct
      last    jmp 0              ;and loop forever

              end start
    PRG

    mars = RuMARS::MARS.new
    warrior = RuMARS::Warrior.new('Imp')
    warrior.parse(prg)
    mars.add_warrior(warrior)
    mars.run(200)
    expect(mars.cycles).to eql(200)
  end

  it 'should support ICWS-94 style immediates' do
    prg = <<~"PRG"
      ;redcode-94
            SPL    #0, }1
            MOV.I  #1234, 1
    PRG

    mars = RuMARS::MARS.new
    warrior = RuMARS::Warrior.new('Imp')
    warrior.parse(prg)
    mars.add_warrior(warrior)
    mars.run(100)
    expect(mars.cycles).to eql(100)
  end
end
