
from pathlib import Path
from lupa.lua51 import LuaRuntime
import unittest
ROOT=Path(__file__).resolve().parents[1]

COMMON=r'''
format=string.format; tinsert=table.insert; max=math.max
function wipe(t) for k in pairs(t) do t[k]=nil end return t end
function newFrame(parent)
 local f={parent=parent,shown=true,width=100,height=16,points={},scripts={},events={}}
 function f:ClearAllPoints() self.points={} end
 function f:SetPoint(...) table.insert(self.points,{...}) end
 f.Point=f.SetPoint
 function f:ClearAndSetPoint(...) self:ClearAllPoints() self:SetPoint(...) end
 function f:SetSize(w,h) self.width=w self.height=h or w end; f.Size=f.SetSize
 function f:SetWidth(v) self.width=v end; f.Width=f.SetWidth
 function f:SetHeight(v) self.height=v end; f.Height=f.SetHeight
 function f:GetWidth() return self.width end
 function f:GetHeight() return self.height end
 function f:GetSize() return self.width,self.height end
 function f:GetFrameLevel() return 1 end
 function f:GetParent() return self.parent end
 function f:SetParent(p) self.parent=p end
 function f:IsShown() return self.shown end; f.IsVisible=f.IsShown
 function f:Show() self.shown=true end
 function f:Hide() self.shown=false end
 function f:SetShown(v) self.shown=not not v end
 function f:SetText(v)
  assert(not self.isFontString or self.fontSet, "SetText(): Font not set")
  self.text=v
 end
 function f:FontTemplate() self.fontSet=true end
 function f:SetFont() self.fontSet=true end
 function f:SetFormattedText(fmt,...) assert(not self.isFontString or self.fontSet,"SetFormattedText(): Font not set");self.text=string.format(fmt,...) end
 function f:GetStringHeight() return 12 end
 function f:SetTextColor(...) self.color={...} end
 function f:SetValue(v) self.value=v end
 function f:SetMinMaxValues(a,b) self.min=a self.max=b end
 function f:CreateTexture() return newFrame(self) end
 function f:CreateFontString() local text=newFrame(self);text.isFontString=true;return text end
 function f:SetScript(k,v) self.scripts[k]=v end
 function f:RegisterEvent(k) self.events[k]=true end
 function f:UnregisterEvent(k) self.events[k]=nil end
 function f:CanChangeProtectedState() return not self.locked end
 function f:IsObjectType() return true end
 function f:GetStatusBarTexture() return self.texture end
 -- Explicit API only: an unknown Set*/Get* call must fail, not silently pass.
 function f:SetFrameStrata(value) assert(type(value)=='string');self.strata=value end
 function f:SetFrameLevel(value) assert(type(value)=='number');self.level=value end
 function f:GetFrameLevel() return self.level or 1 end
 function f:GetScript(event) return self.scripts[event] end
 function f:SetAlpha(value) assert(type(value)=='number');self.alpha=value end
 function f:SetDrawLayer(value) self.drawLayer=value end
 function f:SetShadowOffset(x,y) self.shadowOffset={x,y} end
 function f:SetTexCoord(...) self.texCoord={...} end
 function f:SetTexture(value) self.texture=value end
 function f:SetTextHeight(value) assert(self.fontSet,'SetTextHeight(): Font not set');self.textHeight=value end
 return f
end
frames={}
function CreateFrame(_,name,parent) local f=newFrame(parent); table.insert(frames,f); if name then _G[name]=f end return f end
hooks={}
function hooksecurefunc(a,b,c) if type(a)=='string' then hooks[a]=b else hooks[b]=c end end
C_Timer={After=function(_,_,fn) fn() end}
NP={db={units={}},VisiblePlates={},CreatedPlates={}}
function NP:Pixel(x) return x end; NP.SirusPixel=NP.Pixel
function NP:GetHealth(f) return f.health or 80,f.maxHealth or 100 end
E={media={blankTex='blank'},Libs={LSM={Fetch=function(_,_,v) return v end}},UIParent=newFrame(),oUF={Private={frame_metatable={__index={}}},colors={}}}
function E:GetModule() return NP end
function E:ShortValue(v) return tostring(v) end
function E:ClassColor() return {r=1,g=0,b=0} end
function E:CreateMover() end
ElvUI={E,setmetatable({},{__index=function(_,k) return k end}),{},{nameplates={units={}}},{}}
unitGUIDs={player='PLAYER',target='NPC'}
function UnitGUID(u) return unitGUIDs[u] end
function UnitExists(u) return unitGUIDs[u]~=nil end
function UnitName(u) return u end
function UnitClass() return 'Mage','MAGE' end
function UnitIsPlayer() return false end
function UnitCanAttack() return true end
function GetSpellInfo(x) return tostring(x),nil,'texture' end
'''

def env(before_core=""):
 l=LuaRuntime(unpack_returned_tuples=True);l.execute(COMMON)
 l.execute("""
 DAN={}; E.db={DmgAtNameplates={enable=true,font='font',fontSize=20,fontOutline='OUTLINE',duration=1,showIcon=false,textFormat='none',showDmgToEnemy=true,playerToTargetDamageText=true,showFromAnotherPlayer=true,miss={font='missfont',fontOutline='OUTLINE',fontSize=18},dispel={font='dispelfont',fontOutline='OUTLINE',fontSize=16}}}
 E.Libs.EP={RegisterPlugin=function() end}; function E:GetModule(k) return k=='DmgAtNameplates' and DAN or NP end
 function E:RegisterModule() end
 LibStub=function() return {InExpo=function(_,b,c) return b+c*.5 end,InQuad=function(t,b,c,d) return b+c*t/d end,OutQuint=function(_,b,c) return b+c end,InQuint=function(_,b,c) return b+c end} end
 bit={band=function(a,b) local r,p=0,1 while a>0 and b>0 do if a%2==1 and b%2==1 then r=r+p end a=math.floor(a/2);b=math.floor(b/2);p=p*2 end return r end}
 COMBATLOG_OBJECT_TYPE_PLAYER=1;COMBATLOG_OBJECT_TYPE_NPC=2;COMBATLOG_OBJECT_REACTION_FRIENDLY=4;COMBATLOG_OBJECT_REACTION_HOSTILE=8;COMBATLOG_OBJECT_REACTION_NEUTRAL=16;COMBATLOG_OBJECT_TYPE_PET=32;COMBATLOG_OBJECT_TYPE_GUARDIAN=64;COMBATLOG_OBJECT_AFFILIATION_MINE=128
 SCHOOL_MASK_PHYSICAL=1;SCHOOL_MASK_HOLY=2;SCHOOL_MASK_FIRE=4;SCHOOL_MASK_NATURE=8;SCHOOL_MASK_FROST=16;SCHOOL_MASK_SHADOW=32;SCHOOL_MASK_ARCANE=64
 UIParent=newFrame(); now=0; timeCalls=0; GetTime=function() timeCalls=timeCalls+1 return now end
 frame=newFrame();frame.guid='NPC';frame.unit='nameplate1';frame.Health=newFrame(frame);unitGUIDs.nameplate1='NPC';NP.VisiblePlates[frame]=1
 function DAN:RegisterEvent() end;function DAN:UnregisterEvent() end;function DAN:GetName() return 'DmgAtNameplates' end
 NP.OnShow=function() end;NP.OnHide=function() end
 fonts={};local originalFont=newFrame
 function frame:CreateFontString() local text=originalFont(self);text.isFontString=true;table.insert(fonts,text);return text end
 -- Keep font strings created on arbitrary pooled frames observable.
 local originalCreateFrame=CreateFrame
 CreateFrame=function(...)
  local f=originalCreateFrame(...)
  function f:CreateFontString() local text=originalFont(self);text.isFontString=true;table.insert(fonts,text)
   function text:SetFont(path,size,outline) self.fontSet=true;self.fontCalls=(self.fontCalls or 0)+1;self.fontPathSet=path;self.sizeSet=size end
   function text:SetAlpha(alpha) self.alpha=alpha end
   return text
  end
  function f:SetAlpha(alpha) self.alpha=alpha end
  function f:CreateTexture() local texture=originalFont(self);function texture:SetAlpha(alpha) self.alpha=alpha end;return texture end
  return f
 end
 """)
 if before_core:l.execute(before_core)
 l.execute((ROOT/'Core/Core.lua').read_text());l.execute('DAN.db=E.db.DmgAtNameplates;DAN:PLAYER_ENTERING_WORLD();DAN:InitializePlateIndex()')
 return l

class Runtime(unittest.TestCase):
 def test_lua51(self):
  l=LuaRuntime(unpack_returned_tuples=True);f=l.eval('function(s) local f,e=loadstring(s);return f~=nil,e end')
  self.assertTrue(f((ROOT/'Core/Core.lua').read_text())[0])
 def test_font_initialized_before_first_text(self):
  l=env();l.execute('DAN:DisplayText(frame,"first",20,1,"verticalUp",123,false,"Spell")')
  self.assertEqual(l.eval('fonts[1].text'),'first');self.assertEqual(l.eval('fonts[1].fontCalls'),1)
  l.execute('DAN:DeleteFontString(fonts[1]);DAN:DisplayText(frame,"reused",18,1,"verticalUp",123,false,"Spell","miss")')
  self.assertEqual(l.eval('#fonts'),1);self.assertEqual(l.eval('fonts[1].text'),'reused');self.assertEqual(l.eval('fonts[1].fontPathSet'),'missfont')
 def test_guid_index_hits_do_not_scan(self):
  l=env('scans=0; local original=pairs;pairs=function(t) if t==NP.VisiblePlates then scans=scans+1 end return original(t) end');l.execute('scans=0;for i=1,1000 do assert(DAN:GetNameplateFrame("NPC")==frame) end')
  self.assertEqual(l.eval('scans'),0)
 def test_guid_index_hide_and_reuse(self):
  l=env();l.execute('NP.VisiblePlates[frame]=nil;frame.shown=false;hooks.OnHide({ElvUIFrame=frame})')
  self.assertIsNone(l.eval('DAN:GetNameplateFrame("NPC")'))
  l.execute('frame.shown=true;frame.guid="NEW";unitGUIDs.nameplate1="NEW";NP.VisiblePlates[frame]=1;hooks.OnShow({ElvUIFrame=frame})')
  self.assertIsNone(l.eval('DAN:GetNameplateFrame("NPC")'));self.assertTrue(l.eval('DAN:GetNameplateFrame("NEW")==frame'))
 def test_ignored_events_skip_unit_api(self):
  l=env();l.execute('guidCalls=0;local old=UnitGUID;UnitGUID=function(u) guidCalls=guidCalls+1 return old(u) end;DAN:FilterEvent("CLEU",1,"SPELL_CAST_SUCCESS","PLAYER","player",1,"NPC","mob",10)')
  self.assertEqual(l.eval('guidCalls'),0);self.assertEqual(l.eval('#fonts'),0)
 def test_unrelated_combat_is_rejected_even_with_old_setting(self):
  events=['SPELL_DAMAGE','SPELL_PERIODIC_DAMAGE','RANGE_DAMAGE','SWING_DAMAGE','SPELL_HEAL','SPELL_PERIODIC_HEAL','SPELL_MISSED','SWING_MISSED','SPELL_DISPEL','SPELL_INTERRUPT']
  for enabled in (True,False):
   for event in events:
    with self.subTest(setting=enabled,event=event):
     l=env();l.execute('E.db.DmgAtNameplates.showFromAnotherPlayer='+str(enabled).lower())
     l.execute("calls=0;for _,name in ipairs({'DamageEvent','HealEvent','MissEvent','MissEventPet','DispelEvent','SpellInterruptEvent'}) do DAN[name]=function() calls=calls+1 end end")
     l.globals().combatEvent=event
     l.execute('DAN:FilterEvent("CLEU",1,combatEvent,"OTHER","other",1,"NPC","mob",10,123,"Spell",4,100,0,0,0,0,0,false)')
     self.assertEqual(l.eval('calls'),0)
 def test_personal_combat_routes_to_expected_frame(self):
  for source,target,flags,expected in [('PLAYER','NPC',1,'frame'),('OTHER','PLAYER',1,'DAN.ElvUI_ToPlayerFrame'),('PLAYER','PLAYER',1,'DAN.ElvUI_ToPlayerFrame'),('PET','NPC',160,'frame'),('GUARDIAN','NPC',192,'frame')]:
   with self.subTest(source=source,target=target):
    l=env();l.execute('E.db.DmgAtNameplates.targetToPlayerDamageText=true;E.db.DmgAtNameplates.petToTargetDamageText=true;DAN.DamageEvent=function(_,f) received=f end')
    l.globals().sourceGUID=source;l.globals().destGUID=target;l.globals().sourceFlags=flags
    l.execute('DAN:FilterEvent("CLEU",1,"SPELL_DAMAGE",sourceGUID,"source",sourceFlags,destGUID,"dest",10,123,"Spell",4,100,0,0,0,0,0,false)')
    self.assertTrue(l.eval('received=='+expected))
 def test_foreign_pet_and_unrelated_frame_lookup_rejected(self):
  l=env();self.assertIsNone(l.eval('DAN:GetFrame("OTHER","other",1,"NPC","mob",10)'))
  self.assertIsNone(l.eval('DAN:GetFrame("FOREIGNPET","pet",32,"NPC","mob",10)'))
  self.assertTrue(l.eval('DAN:GetFrame("OTHER","other",1,"PLAYER","player",1)==DAN.ElvUI_ToPlayerFrame'))
 def test_personal_direction_toggles_still_apply(self):
  l=env();l.execute('E.db.DmgAtNameplates.playerToTargetDamageText=false;DAN:FilterEvent("CLEU",1,"SPELL_DAMAGE","PLAYER","player",1,"NPC","mob",10,123,"Spell",4,100)')
  self.assertEqual(l.eval('#fonts'),0)
 def test_disabled_animation_does_not_allocate(self):
  l=env();l.execute('DAN:DisplayText(frame,"text",20,1,"disabled",123,false,"Spell")');self.assertEqual(l.eval('#fonts'),0)
 def test_animation_pool_time_and_alpha(self):
  l=env();l.execute('E.db.DmgAtNameplates.showIcon=true;for i=1,3 do DAN:DisplayText(frame,"hit",20,.4,"verticalUp",123,false,"Spell") end;now=.2;timeCalls=0;DAN.DmgTextFrame.scripts.OnUpdate()')
  self.assertEqual(l.eval('timeCalls'),1);self.assertAlmostEqual(l.eval('fonts[1].alpha'),.2);self.assertAlmostEqual(l.eval('fonts[1].icon.alpha'),.2)
  l.execute('now=2;DAN.DmgTextFrame.scripts.OnUpdate();DAN:DisplayText(frame,"new",20,1,"verticalUp",123,false,"Spell")')
  self.assertEqual(l.eval('#fonts'),3)
 def test_critical_restores_event_font(self):
  l=env();l.execute('DAN:DisplayText(frame,"miss",18,1,"verticalUp",123,true,"Spell","miss");now=.3;DAN.DmgTextFrame.scripts.OnUpdate()')
  self.assertEqual(l.eval('fonts[1].fontPathSet'),'missfont');self.assertEqual(l.eval('fonts[1].sizeSet'),18)
 def test_recycled_plate_clears_text(self):
  l=env();l.execute('DAN:DisplayText(frame,"old",20,1,"verticalUp",123,false,"Spell");frame.guid="OTHER";DAN.DmgTextFrame.scripts.OnUpdate()')
  self.assertFalse(l.eval('fonts[1].shown'));self.assertIsNone(l.eval('fonts[1].nameplateFrame'))
 def test_legacy_fallback(self):
  l=env();l.execute('NP.VisiblePlates={};legacy=newFrame();legacy.guid="LEGACY";NP.PlateGUID={LEGACY=legacy}')
  self.assertTrue(l.eval('DAN:GetNameplateFrame("LEGACY")==legacy'))

if __name__=='__main__':unittest.main(verbosity=2)
