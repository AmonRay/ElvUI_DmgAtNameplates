import unittest
from test_runtime import env

def combat(l,event,payload,source='PLAYER',target='NPC',flags=1):
 l.globals().combatEvent=event;l.globals().source=source;l.globals().target=target;l.globals().flags=flags
 l.execute('DAN.DmgTextFrame.scripts.OnEvent(DAN.DmgTextFrame,"COMBAT_LOG_EVENT_UNFILTERED",1,combatEvent,source,"source",flags,target,"dest",10,'+payload+')')

def configured():
 l=env();l.execute('''local db=DAN.db;db.petToTargetDamageText=true;db.targetToPlayerDamageText=true
 db.autoAttackPlusCritAnimation='verticalUp';db.autoAttack='fountain';db.critAnimation='verticalUp';db.commonDMGAnimation='fountain'
 db.interrupt={font='interruptfont',fontSize=17,fontOutline='OUTLINE'}
 db.playerToTargetHealText=true;db.petToTargetHealText=true;db.targetToPlayerHealText=true;db.showOverHeal=true
 ACTION_SPELL_MISSED_MISS='Miss' ''');return l

class CombatPayloads(unittest.TestCase):
 def test_swing_critical_end_to_end_in_all_directions(self):
  for source,target,flags in [('PLAYER','NPC',1),('OTHER','PLAYER',1),('PET','NPC',160),('GUARDIAN','NPC',192)]:
   for crit in ('true','false'):
    with self.subTest(source=source,crit=crit):
     l=configured();combat(l,'SWING_DAMAGE','100,0,1,0,0,0,'+crit+',false,false',source,target,flags)
     self.assertEqual(l.eval('#fonts'),1);self.assertEqual(l.eval('fonts[1].pow'),crit=='true');self.assertIn('100',l.eval('fonts[1].text'))
     self.assertTrue(l.eval('fonts[1].nameplateFrame==frame') if target=='NPC' else l.eval('fonts[1].nameplateFrame==nil'))
 def test_swing_miss_reason_end_to_end(self):
  for source,target,flags in [('PLAYER','NPC',1),('OTHER','PLAYER',1),('PET','NPC',160),('GUARDIAN','NPC',192)]:
   for reason,label in [('DODGE','Dodge'),('PARRY','Parry'),('MISS','Miss')]:
    with self.subTest(source=source,reason=reason):
     l=configured();combat(l,'SWING_MISSED','"'+reason+'",false',source,target,flags)
     self.assertEqual(l.eval('#fonts'),1);self.assertIn(label,l.eval('fonts[1].text'))
 def test_spell_payloads_still_reach_real_rendering(self):
  for event in ('SPELL_DAMAGE','SPELL_PERIODIC_DAMAGE','RANGE_DAMAGE'):
   l=configured();combat(l,event,'123,"Spell",4,120,0,4,0,0,0,true');self.assertTrue(l.eval('fonts[1].pow'));self.assertIn('120',l.eval('fonts[1].text'))
  l=configured();combat(l,'SPELL_MISSED','123,"Spell",4,"PARRY"');self.assertIn('Parry',l.eval('fonts[1].text'))
  l=configured();combat(l,'SPELL_HEAL','123,"Heal",2,75,0,0,true');self.assertIn('75',l.eval('fonts[1].text'))
 def test_disabled_swing_directions_and_unrelated_combat_do_not_render(self):
  for source,target,flags,toggle in [('PLAYER','NPC',1,'playerToTargetDamageText'),('OTHER','PLAYER',1,'targetToPlayerDamageText'),('PET','NPC',160,'petToTargetDamageText')]:
   for event,payload in [('SWING_DAMAGE','100,0,1,0,0,0,true'),('SWING_MISSED','"PARRY",false')]:
    l=configured();l.execute('DAN.db.'+toggle+'=false');combat(l,event,payload,source,target,flags);self.assertEqual(l.eval('#fonts'),0)
  for source,flags in [('OTHER',1),('FOREIGNPET',32)]:
   l=configured();combat(l,'SWING_DAMAGE','100,0,1,0,0,0,true',source,'NPC',flags);self.assertEqual(l.eval('#fonts'),0)

class EventFont(unittest.TestCase):
 def test_real_miss_handler_uses_miss_font_and_restores_it_after_animation(self):
  for event,payload in [('SWING_MISSED','"DODGE",false'),('SPELL_MISSED','123,"Spell",4,"PARRY"')]:
   l=configured();combat(l,event,payload)
   self.assertEqual(l.eval('fonts[1].fontPathSet'),'missfont')
   l.execute('now=.3;DAN.DmgTextFrame.scripts.OnUpdate()')
   self.assertEqual(l.eval('fonts[1].fontPathSet'),'missfont');self.assertEqual(l.eval('fonts[1].sizeSet'),18)

class EventAlpha(unittest.TestCase):
 def test_event_alpha_reaches_text_icon_and_animation(self):
  for source,flags,event,payload,category in [
   ('PLAYER',1,'SPELL_MISSED','123,"Spell",4,"DODGE"','miss'),
   ('PET',160,'SWING_MISSED','"PARRY",false','miss'),
   ('PLAYER',1,'SPELL_DISPEL','123,"Dispel",2,456,"Aura",4,"BUFF"','dispel'),
   ('PLAYER',1,'SPELL_INTERRUPT','123,"Interrupt",1,456,"Interrupted",4','interrupt')]:
   for alpha in (0,.2,.75,1):
    with self.subTest(event=event,alpha=alpha):
     l=configured();l.execute('DAN.db.showIcon=true;DAN.db.'+category+'.fontAlpha='+str(alpha))
     combat(l,event,payload,source,'NPC',flags)
     self.assertEqual(l.eval('#fonts'),1);self.assertAlmostEqual(l.eval('fonts[1].startAlpha'),alpha)
     self.assertAlmostEqual(l.eval('fonts[1].alpha'),alpha);self.assertAlmostEqual(l.eval('fonts[1].icon.alpha'),alpha)
     l.execute('now=.2;DAN.DmgTextFrame.scripts.OnUpdate()')
     self.assertAlmostEqual(l.eval('fonts[1].alpha'),alpha*.5);self.assertAlmostEqual(l.eval('fonts[1].icon.alpha'),alpha*.5)
 def test_missing_event_alpha_defaults_to_one(self):
  l=configured();combat(l,'SWING_MISSED','"DODGE",false');self.assertEqual(l.eval('fonts[1].startAlpha'),1)
 def test_reused_font_reads_new_profile_alpha(self):
  l=configured();l.execute('DAN.db.miss.fontAlpha=.2');combat(l,'SWING_MISSED','"DODGE",false')
  l.execute('DAN:DeleteFontString(fonts[1]);local old=DAN.db;E.db.DmgAtNameplates={};for k,v in pairs(old) do E.db.DmgAtNameplates[k]=v end;E.db.DmgAtNameplates.miss={font="newfont",fontSize=19,fontOutline="OUTLINE",fontAlpha=.7}')
  combat(l,'SWING_MISSED','"PARRY",false');self.assertEqual(l.eval('#fonts'),1);self.assertEqual(l.eval('fonts[1].fontPathSet'),'newfont');self.assertAlmostEqual(l.eval('fonts[1].startAlpha'),.7)

SCAN_COUNTER='scans=0;local original=pairs;pairs=function(t) if t==NP.VisiblePlates then scans=scans+1 end return original(t) end'
def indexed():
 l=env(SCAN_COUNTER);l.execute('scans=0');return l

class NegativeGUIDCache(unittest.TestCase):
 def test_repeated_miss_scans_once_and_expires(self):
  l=indexed();l.execute('for i=1,1000 do assert(not DAN:GetNameplateFrame("MISSING")) end')
  self.assertEqual(l.eval('scans'),1)
  l.execute('now=.099;assert(not DAN:GetNameplateFrame("MISSING"))');self.assertEqual(l.eval('scans'),1)
  l.execute('now=.101;assert(not DAN:GetNameplateFrame("MISSING"))');self.assertEqual(l.eval('scans'),2)
 def test_show_invalidates_negative_cache_without_waiting(self):
  l=indexed();l.execute('''DAN:GetNameplateFrame('NEW');frame.guid='NEW';unitGUIDs.nameplate1='NEW';hooks.OnShow({ElvUIFrame=frame})''')
  self.assertTrue(l.eval('DAN:GetNameplateFrame("NEW")==frame'))
 def test_hide_and_recycle_invalidate_and_revalidate(self):
  l=indexed();l.execute('''DAN:GetNameplateFrame('NEW');frame.shown=false;NP.VisiblePlates[frame]=nil;hooks.OnHide({ElvUIFrame=frame})
  assert(not DAN:GetNameplateFrame('NPC'));frame.guid='NEW';unitGUIDs.nameplate1='NEW';frame.shown=true;NP.VisiblePlates[frame]=1;hooks.OnShow({ElvUIFrame=frame})''')
  self.assertTrue(l.eval('DAN:GetNameplateFrame("NEW")==frame'));self.assertIsNone(l.eval('DAN:GetNameplateFrame("NPC")'))
 def test_legacy_mapping_bypasses_a_cached_miss(self):
  l=indexed();l.execute('''DAN:GetNameplateFrame('LEGACY');legacy=newFrame();legacy.guid='LEGACY';NP.PlateGUID={LEGACY=legacy}''')
  self.assertTrue(l.eval('DAN:GetNameplateFrame("LEGACY")==legacy'))
 def test_unhooked_visible_plate_recovers_after_expiry(self):
  l=indexed();l.execute('''DAN:GetNameplateFrame('NEW');frame.guid='NEW';unitGUIDs.nameplate1='NEW';assert(not DAN:GetNameplateFrame('NEW'));now=.101''')
  self.assertTrue(l.eval('DAN:GetNameplateFrame("NEW")==frame'))
 def test_negative_cache_is_bounded(self):
  l=indexed();l.execute('''for i=1,1000 do DAN:GetNameplateFrame('missing'..i) end;scans=0
  for i=1,128 do DAN:GetNameplateFrame('missing'..i) end''')
  self.assertEqual(l.eval('scans'),0)
  l.execute('DAN:GetNameplateFrame("missing1000")');self.assertEqual(l.eval('scans'),1)
 def test_disable_enable_clears_negative_cache(self):
  l=indexed();l.execute('''DAN:GetNameplateFrame('NEW');DAN:OnDisable();DAN:OnEnable();frame.guid='NEW';unitGUIDs.nameplate1='NEW' ''')
  self.assertTrue(l.eval('DAN:GetNameplateFrame("NEW")==frame'))
 def test_scan_counter_observes_real_fallback(self):
  l=indexed();l.execute('DAN:GetNameplateFrame("MISSING")');self.assertEqual(l.eval('scans'),1)

class StrictAPI(unittest.TestCase):
 def test_unknown_methods_are_not_accepted(self):
  l=env()
  for method in ('SetInventedMethod','GetInventedMethod'):
   self.assertFalse(l.eval('pcall(function() newFrame():'+method+'() end)')[0])
 def test_uninitialized_font_is_rejected(self):
  l=env();self.assertFalse(l.eval('pcall(function() local text=newFrame():CreateFontString();text:SetText("bad") end)')[0])
  self.assertFalse(l.eval('pcall(function() newFrame():SetTextHeight(12) end)')[0])
 def test_all_animation_paths_use_explicit_api(self):
  for animation in ('verticalUp','verticalDown','fountain','rainfall'):
   l=configured();l.globals().animation=animation
   l.execute('DAN.db.showIcon=true;DAN:DisplayText(frame,"hit",20,.6,animation,123,true,"Spell");now=.05;DAN.DmgTextFrame.scripts.OnUpdate();now=.3;DAN.DmgTextFrame.scripts.OnUpdate();now=2;DAN.DmgTextFrame.scripts.OnUpdate()')
   self.assertFalse(l.eval('fonts[1].shown'));self.assertFalse(l.eval('fonts[1].icon.shown'))
 def test_disable_cleans_text_and_event_registration(self):
  l=configured();combat(l,'SWING_DAMAGE','100,0,1,0,0,0,true')
  l.execute('DAN.db.enable=false;DAN:OnDisable()');self.assertFalse(l.eval('fonts[1].shown'))
  self.assertIsNone(l.eval('DAN.DmgTextFrame:GetScript("OnUpdate")'));self.assertIsNone(l.eval('DAN.DmgTextFrame.events.COMBAT_LOG_EVENT_UNFILTERED'))
  combat(l,'SWING_DAMAGE','100,0,1,0,0,0,true');self.assertEqual(l.eval('#fonts'),1);self.assertFalse(l.eval('fonts[1].shown'))

class ShippedProfile(unittest.TestCase):
 def test_real_profile_defaults_render_personal_combat(self):
  from test_runtime import ROOT
  for event,payload,source,flags in [
   ('SWING_DAMAGE','100,0,1,0,0,0,true','PLAYER',1),
   ('SWING_MISSED','"PARRY",false','PET',160),
   ('SPELL_MISSED','123,"Spell",4,"DODGE"','PLAYER',1),
   ('SPELL_HEAL','123,"Heal",2,100,0,0,true','PLAYER',1),
   ('SPELL_DISPEL','123,"Dispel",2,456,"Aura",4,"BUFF"','PLAYER',1),
   ('SPELL_INTERRUPT','123,"Interrupt",1,456,"Interrupted",4','PLAYER',1)]:
   l=env();l.execute((ROOT/'Settings/Profile.lua').read_text());l.execute('E.db=ElvUI[4]')
   combat(l,event,payload,source,'NPC',flags)
   self.assertEqual(l.eval('#fonts'),1);self.assertEqual(l.eval('fonts[1].fontPathSet'),'PT Sans Narrow')
 def test_real_profile_rejects_foreign_combat(self):
  from test_runtime import ROOT
  l=env();l.execute((ROOT/'Settings/Profile.lua').read_text());l.execute('E.db=ElvUI[4]')
  combat(l,'SWING_DAMAGE','100,0,1,0,0,0,true','OTHER','NPC',1);self.assertEqual(l.eval('#fonts'),0)
 def test_addon_version_and_update_source_are_unchanged(self):
  from test_runtime import ROOT
  toc=(ROOT/'ElvUI_DmgAtNameplates.toc').read_text()
  self.assertIn('## Version: 1.16',toc)
  self.assertEqual([line for line in toc.splitlines() if line.startswith('## X-Sirus-Update:')],['## X-Sirus-Update: https://github.com/fxpw/ElvUI_DmgAtNameplates/tree/master'])
