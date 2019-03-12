-- title:  Doors of Doom
-- author: msx80
-- desc:   Open doors and fight monsters!
-- script: lua

local LEFT = 1
local RIGHT = 2
local HEAD = 3
local BODY = 4
local LEGS = 5
local places = {"Left hand", "Right hand", "Head", "Body", "Legs"}
local placeOffsets={ {2, 18}, {30,18}, {16,2},{16,16}, {16,30} }
local defaultEquip = {257,258,256, 259,260}


--[[


Idee:
Craft Table:
mostra le combinazioni che hai:
"You can't craft now"
"Craft 2 tails and 2 leaves"
"Craft 5 diamonds"

Quando le fa, ti dice cosa hai ottenuto

Negozi:
due o tre oggetti comprabili per negozio

]]

t=0

function deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[deepcopy(orig_key)] = deepcopy(orig_value)
        end
        setmetatable(copy, deepcopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

function multiset(cont, item, qty)
 if qty > 0 then
  cont[item]=qty
 else
  cont[item]=nil
 end
 return qty
end

function multiadd(cont, item, delta)
  local n = cont[item]
  if not n then n = 0 end
  n = n + delta
  return multiset(cont, item, n)
end

function iff(cond, a, b)
 if cond then 
   return a 
 else 
   return b 
 end
end
function nvl(a, b)
 if a then 
   return a 
 else 
   return b 
 end
end

function printc(s,x,y,c)
 local w=print(s,0,-8)
 print(s,x-(w/2),y,c or 15)
end

function richPrint(tokens, sx, sy)
  if type(tokens)=="string" then
    print(tokens,sx,sy,15,false,1,false)
  else
    for n=1,#tokens,2 do
      local str = tokens[n+1]
      local c = tokens[n]
      local w
      if c == -1 then
       spr(str, sx, sy-1)
       w = 8
      else
       w = print(str,sx,sy,c,false,1,false)
      end
      sx=sx+w
    end
  end
end


function big(text, x, y, c)
 local w = print(text, 0, -50, c, false, 2)
 print(text, x-(w//2)+1, y+1, 15, false, 2)
 print(text, x-(w//2)-1, y+1, 15, false, 2)
 print(text, x-(w//2)+1, y-1, 15, false, 2)
 print(text, x-(w//2)-1, y-1, 15, false, 2)
 print(text, x-(w//2), y, c, false, 2)

end

function inRange(range, val)
return val <= range.max and val >= range.min
end
function range(min, max)
 return {min=min, max=max}
end


currentStep=nil

anims = {
  update = function(self)
  if #self > 0 then
    local a = self[1]
    a:draw()
    a.time = a.time + 1
    if a.time == a.ttl then 
   table.remove(self, 1)
   if a.onEnd then
     a:onEnd()
   end
    end
  end
 end,
  add = function(self, anim)
 table.insert(self, anim)
 anim.time = 0
  end

} -- all animations in queue


log = {
  lines = {
    {0,""}, 
    {0,""}, 
    {0,""}, 
    {15,"Welcome to",6," Doors of Doom",15,"!"}, 
    {14,"Fight your way deep into the dungeon"}
  },
  add = function (self, lin)
    table.remove(self.lines, 1)
    table.insert(self.lines, lin)
  end,
  print=function(self,x,y)
   for i=1,#self.lines do
    local tokens = self.lines[i]
    local sy = y+(i-1)*7
    local sx = x
    richPrint(tokens, sx, sy)
   end
  end, 
}

invWidget = nil
craftWidget = nil

-- crea un widget con item selezionabili. Gli item devono avere una "label"
-- di tipo richtext ed eventualmente un "callback" che viene chiamato
-- alla selezione
function makeWidget(items, maxShown, xcallback, extraDraw)
 local w= {
  current = 1,
  scroll = 0,
  ensureOk=function(self)
    if self.current > #items then
	  self.current = #items
	end
	if self.scroll> #items-maxShown then
	 self.scroll = #items-maxShown
	end
    if #items > maxShown then 
	  
	  while self.current-self.scroll>maxShown do
	    self.scroll = self.scroll +1
	  end
	  while self.current-self.scroll<=0 do
	    self.scroll = self.scroll -1
	  end
	else
	  self.scroll = 0
	end
  end,
  update=function(self)
   if btnp(0) then
     if self.current == 1 then
       self.current = #items
     else
       self.current = self.current-1
     end
   end
   if btnp(1) then
     if self.current == #items then
       self.current = 1
     else
       self.current = self.current+1
     end
   end
   if btnp(5) and xcallback then
     xcallback()
   end
   if btnp(4) then
     local c = items[self.current].callback
	 if c then c() end
   end

   self:ensureOk()
  end,
  
  draw=function(self,x,y)
  
   if extraDraw then extraDraw(items[self.current], x, y) end
   for i=1,math.min(#items,maxShown) do
    local it = items[i+self.scroll]
    if (i+self.scroll)==self.current and ( (t//10)%2 == 0) then
      print(">", x, y+(i-1)*9, 15)
    end
    richPrint(it.label,x+4,y+(i-1)*9,15,false,1,false)
   end
      
   
      
  end
}
return w
end

function displayItem(item,x,y)

   spr(item.spr,x,y,-1, 2)
   
   local yy=y+20
   richPrint({5, item.name, },x,yy,15,false,1,false)
   yy=yy+10
   if item.usable then
     rectb(24+x, 7+y, 50, 9, 14)
     print("Z TO USE", 28+x, 9+y, 6)
     richPrint({10, "- Usable: "..item.usable.name },x,yy,15,false,1,false)
     yy=yy+7
   end
   if item.combat then
     richPrint({10, "- Combat: "..item.combat.name },x,yy,15,false,1,false)
     yy=yy+7
   end
   if item.attack then
     richPrint({10, "- Attack: "..item.attack.min.."-"..item.attack.max },x,yy,15,false,1,false)
     yy=yy+7
   end
   if item.armour then
     local sgn = iff(item.armour>0, "+", "")
     richPrint({10, "- Armour: "..sgn..item.armour },x,yy,15,false,1,false)
     yy=yy+7
   end
   if item.equip then
     if isEquipped(item) then
       rectb(24+x, 7+y, 70, 9, 14)
       print("Z TO REMOVE", 28+x, 9+y, 6)
     else
       rectb(24+x, 7+y, 60, 9, 14)
       print("Z TO EQUIP", 28+x, 9+y, 6)
     end
     richPrint({10, "- Equip: "..places[item.equip.place] },x,yy,15,false,1,false)
     yy=yy+7
   end
   if item.flavour then
      yy=yy+2
      for i=1,#item.flavour do
       richPrint({15, item.flavour[i]},x,yy,15,false,1,false)
       yy=yy+7
      end
   end
end

function drawInvBackground(item,x,y)
   rect(x-5,y-5,240,12*8,0)
   rectb(x-5,y-5,130,12*8,1)
   rectb(x+124,y-5,106,12*8,1)

   if item then 
    displayItem(item, 127+x,5)
   end

end
function refreshCommandWidget()
 local oldCurrent = widget.current
 local oldScroll = widget.scroll
 makeCommandWidget(currentStep.actions())
 widget.current = oldCurrent
 widget.scroll = oldScroll
 widget:ensureOk()
end
function refreshInvWidget()
 if invWidget then
  local oldCurrent = invWidget.current
  local oldScroll = invWidget.scroll
  invWidget = makeInventoryWidget()
  invWidget.current = oldCurrent
  invWidget.scroll = oldScroll
  invWidget:ensureOk()
 end  
end

function makeInventoryWidget()
 -- transform inventory to list
 local inv = {}
 for k,v in pairs(pg.inventory) do
   local elem = { 
     item=k, 
	 qty=v, 
	 label={-1, k.spr, 
        15, " "..k.name, 
        14, " ["..v.."]"}, --, 15, iff(isEquipped(k), "E", "o")},
	 callback=function()
		if k.usable then
		  k.usable.onUse(k)
				sfx(4,40,15)
		  refreshCommandWidget()
		elseif k.equip then
		  if isEquipped(k) then
		    unequip(k.equip.place) 
		  else
		    equip(k) 
		  end
		  refreshInvWidget()
		end
	 end
   }
   table.insert(inv, elem)
 end
 table.sort(inv, function(a,b)
   return a.item.name<b.item.name
 end)
 
local w=makeWidget(inv, 10, function() invWidget = nil end, function(item, x, y) drawInvBackground(item.item,x,y) end)

return w
end

function makeCraftWidget()
 
 -- label = {-1, 304,7,"x2 ", -1, 305, 7, "x4 ", -1, 313, 7, "x4 "},
 local inv = {
   
 }
 for i=1,#CRAFTS do
  if canCraft(CRAFTS[i]) then
   local s = {-1, CRAFTS[i].output.spr, 15, " <= "}

  for k,v in pairs(CRAFTS[i].ingredients) do
    table.insert(s, -1)
	table.insert(s, k.spr)
    table.insert(s, 15)
	table.insert(s, " "..v.." ")
  end
  table.insert(inv, { label = s, callback = function()
    craftWidget = nil
    doCraft(CRAFTS[i]) 
  end})
		end
 end
 
	if #inv == 0 then
  log:add({15, "You can't craft anything yet.." })
		return
	end
 
 local w=makeWidget(inv, 10, function() craftWidget = nil end, function(item, x, y)
  --drawInvBackground(item.item,x,y) 
  rect(x-12,y-12,104,104,0)
  rectb(x-11,y-11,102,102,9)
  print("Buy/Craft what?", x,y-9,6)
  
 end)

return w
end


function makeCommandWidget(items)
  widget=makeWidget(items, 9, nil, nil)
end


 -- dati del giocatore
 pg={
  maxHp = 20,
  hp=20,
  inventory={
  },
  equip={ -- map PLACE, ITEM
  },
  blockedRemainder=0,
  
  -- dati calcolati
  attack = range(2,4), 
  armour = 0,
  
 }


game={
 door=false,  -- open ?
 monster=nil, -- current monster behind door
 loot=nil,     -- current loot displayed
 gold=nil, -- gold from monster
 effects={}, -- key: effect, value: turns
 level=0
}

function ricalcolaPg()
 -- ricalcola i dati del pg
 -- in base alle robe che ha addosso
 -- etc
 
 -- attack
 local weapon = pg.equip[LEFT]
 local base
 if weapon then
  base = weapon.attack
 else
  base = range(2,4 ) 
 end
 local b = 0
 if isEffectActive(EFFECTS.MUSCLES) then
  b = 5
 end
 pg.attack = range(base.min+b, base.max+b) 
 
 -- armour
 local arm = 0
 for i=LEFT,LEGS do
   local e = pg.equip[i]
   if e and e.armour then arm=arm+e.armour end
 end
 pg.armour = arm
 
 -- maxHp
 --pg.maxHp = pg.level*10
 if pg.hp > pg.maxHp then
   pg.hp = pg.maxHp
 end
end

function unequip(place)
  local item = pg.equip[place];
  if item then
    log:add({15, "You unequip ", 14, item.name })
    sfx(6,18,20)
    pg.equip[place] = nil
    ricalcolaPg()
  else
    log:add({15, "You have nothing there (?)" })
  end
end

function equip(item)
  sfx(6,15,20)
  log:add({15, "You equip ", 14, item.name })
  pg.equip[item.equip.place] = item
  ricalcolaPg()
end

function isEquipped(item)
 for k,v in pairs(pg.equip) do
   if v == item then return k end
 end
 return false
end

function enterStep(step)
  if currentStep and currentStep.exit then
    currentStep.exit()
  end
  currentStep = step
  if step.enter then
    step.enter()
  end
  makeCommandWidget(step.actions())
end


function drawDoor(open)
  if open then
     spr(0,0,0,-1,1,0,0,12,12)
     if game.monster then
       local m = game.monster
       --printc(m.name,50, 33,7, true)
       print(m.hp.."/"..m.maxHp,60, 90,6, false, 1, true)
    print(m.attack.min.."-"..m.attack.max,10, 90,5, false, 1, true)
       spr(m.spr,
       34,-- +math.sin(t/30)*2  ,
       45,-- +math.sin(t/36)*2 ,
       -1,1,0,0,4,4)
     elseif game.loot then

       spr(ITEMS.Gold.spr,38,30,-1,1,0,0,1,1)
       print("x"..game.gold, 48, 32)
       printc("Gold", 50, 42)

       spr(game.loot.item.spr,38,60,-1,1,0,0,1,1)
       print("x"..game.loot.qty, 48, 62)
       printc(game.loot.item.name, 50, 72)
     end
  else
     rect(0,0,8*12,8*12,4)
     line(4*12,0, 4*12, 8*12-1, 1)
     spr(0,0,0,0,1,0,0,12,12)
     spr(261, 30, 50, 0, 1, 0, 0, 2, 2)
     spr(261, 55, 50, 0, 1, 0, 0, 2, 2)
     
  end
end

function printSmallRight(text,x,y,c)
 local w = print(text,0,-20,c, true, 1, true)
 print(text,x-w,y,c, true, 1, true)
end

function printStats(x, y)
 print("Life",x,y,6, true, 1, true)
 printSmallRight(pg.hp.."/"..pg.maxHp,x+63,y,6)

 print("Attack",x,y+6,5, true, 1, true)
 printSmallRight(pg.attack.min.."-"..pg.attack.max,x+63,y+6,5)

 print("Armour",x,y+12,12, true, 1, true)
 printSmallRight(pg.armour,x+63,y+12,12)

-- print("Exper.",x,y+18,13, true, 1, true)
-- printSmallRight("boh",x+63,y+18,13)

 print("Keys",x,y+18,9, true, 1, true)
 printSmallRight(pg.inventory[ITEMS.Key],x+63,y+18,9)
 
 print("Level",x,y+24,10, true, 1, true)
 printSmallRight(game.level,x+63,y+24,10)
 
end

function drawEquip(cx, cy)
 rectb(cx+14,cy   ,12,12,8)
 rectb(cx,   cy+16,12,12,8)
 rectb(cx+14,cy+14,12,12,8)
 rectb(cx+28,cy+16,12,12,8)
 rectb(cx+14,cy+28,12,12,8)

 local eq = pg.equip
 for i=LEFT,LEGS do
  local sp = defaultEquip[i]
  if eq[i] then sp = eq[i].spr end
  spr(sp,cx+placeOffsets[i][1], cy+placeOffsets[i][2], 8)
 end

 -- effects
 local ey = cy
 for k,v in pairs(game.effects) do
   spr(k.spr, cx+44, ey,8)
   print(v, cx+44+9, ey+1)
   ey = ey + 9
 end
 
 --rect(cx+44, cy+9,8,8,8)
 --print("2", cx+44+9, cy+1+9)

end

function drawBottom()
 rect(0,8*12+1,240,1,4)
 rect(0,8*12+2,240,1,1)
 rect(0,8*12+4,240,36,1)
 
 log:print(1,8*13+4-7)
end

function drawGame()
 print("NOW WHAT?", 8*13+1, 1,6)
-- print("AA(enter)", 8*12+2, 91,3)
 
 widget:draw(8*12+3, 10)

 rectb(174,0,66,12*8,1)

 spr(279,174,0,0) 
 spr(279,232,0,0) 
 spr(279,174,88,0) 
 spr(279,232,88,0) 
 print("Stats",190, 2)

 
 printStats(1+20+ 8*13+51,8)

 print("Equip:",1+20+ 8*13+51, 8+32)
 
 cx = 16+8*13+51+5
 cy = 50
 drawEquip(cx, cy)
end

function TIC()

 cls(0)

 -- this is always visible
 drawBottom()
 
 if #anims == 0 then
   -- route inputs to widgets only if no animation is running
   if invWidget then
     invWidget:update()
   elseif craftWidget then
    craftWidget:update()
   else
     widget:update()
   end
 end
 
 if invWidget then
     invWidget:draw(5,5)
 else
    drawDoor(game.door)
    drawGame()
	if craftWidget then
	  craftWidget:draw(80,12)
	end

 end
 
 anims:update() 

 t=t+1
end

function rnd(range)
 if type(range)=="number" then
  return math.random(0,range)
 else
  return math.random(range.min, range.max)
 end
end
function chooseMonster()
local eligibles = {}
for i=1,#MONSTERS do
 if inRange(MONSTERS[i].levels, game.level) then
   table.insert(eligibles, MONSTERS[i])
 end
end
return eligibles[math.random(1,#eligibles)]
end

function onOpenDoorEnter()
  -- choose monster and stuff
  log:add({15,"-----------------------"})
  game.door = true
  game.monster = deepcopy(chooseMonster())
  game.monster.maxHp = rnd(game.monster.maxHpRange)
  game.monster.hp = game.monster.maxHp
  game.level=game.level+1
  log:add({15,"You open the door and find ",5,game.monster.name,15,"!"})
  inventoryAdd(ITEMS.Key, -1)  
end


function onOutDoorEnter()
  game.monster = nil
  game.loot = nil
  game.gold = nil
  game.door = false
  damage(pg,-1)
end

function damage(ent, val)
  ent.hp = ent.hp - val
  if ent.hp<0 then
    ent.hp = 0
  elseif ent.hp > ent.maxHp then
    ent.hp = ent.maxHp
  end
end

function doEnemyTurn()
 if isEffectActive(EFFECTS.SMOKE) then
  log:add({5,game.monster.name,15," can't find you becouse of ",
 9,EFFECTS.SMOKE.name })
  return
 end
 
 if isEffectActive(EFFECTS.GHOSTLY) then
  if math.random(1,100)>50 then
    log:add({5,game.monster.name,15," misses you becouse of ", 9,EFFECTS.GHOSTLY.name })
    return
  end
 end
 
 
	 local dmg = rnd(game.monster.attack)
	 local blockedFloat = dmg * pg.armour / 100
	 local blocked = math.floor(blockedFloat)
	 local blockedRemainder = blockedFloat - blocked
	 pg.blockedRemainder = pg.blockedRemainder + blockedRemainder
	 trace(pg.blockedRemainder)
	 if pg.blockedRemainder > 1 then
	   pg.blockedRemainder = pg.blockedRemainder -1
	   blocked = blocked +1
	 end
	 local realdmg = math.max(0, dmg - blocked)
	 damage(pg, realdmg)
	 log:add({5,game.monster.name,15," deals ",
	 6,dmg,
	 12, " (-"..blocked..")",
	 15," damages to you!"
	 })
	 sfx(1,15,15)

	 anims:add(makeAnimRaisingString("-"..realdmg, 205, 50,6,function(self)
	   if pg.hp <= 0 then
			log:add({5,game.monster.name,15," defeats you!"})
			enterStep(STEP.OUTDOOR)
	   else
		 enterStep(STEP.OURTURN)
	   end
	  end));
 
end

function calcLoot(l)
 -- calcola il loot di un mostro
 -- con probabilita
 local sum = 0
 for i=1,#l do
   sum = sum + l[i].prob
 end
 local v = math.random(sum)
 for i=1,#l do
   v = v - l[i].prob
   if v<=0 then
     return l[i]
   end
 end

end

function killMonster()
 local l = calcLoot(game.monster.loot)
 local q
 if type(l.qty)=="number" then
   q = l.qty
 else
   q = rnd(l.qty)
 end
 game.loot = {
  qty = q,
  item = l.item
 }
 game.gold = rnd(game.monster.gold)
 game.monster = nil
end

function inventoryAdd(item, qty)
  -- all ivnentory change pass by here
  local remaining =  multiadd(pg.inventory, item, qty)
  
  if remaining == 0 then
    -- remove stuff from equip if no longer available
    local place = isEquipped(item);
    if place then
   unequip(place)
 end
  end
  
    refreshInvWidget()
  
  return remaining  
end

function lootActions()
  -- function () return {"Pick Up Loot", "Leave it"} end,
  local r = {
 { label = "Pick Up Loot", callback = function()
    log:add({15, "You pick up ",9,game.loot.qty.."x ", 14, game.loot.item.name })
    inventoryAdd(game.loot.item, game.loot.qty)
	inventoryAdd(ITEMS.Gold, game.gold)
    enterStep(STEP.OUTDOOR)
 end },
 { label = "Leave it", callback = function() 
  log:add({15, "You ignore the loot" })
  enterStep(STEP.OUTDOOR)
 end }
  }
  return r

end


function unimplemented()
 log:add("Unimplemented! :D");
end

function openDoorActions()
  local r = {
 {label="Continue", callback = function () enterStep(STEP.OURTURN) end },
  }
  return r
end


function outDoorActions()
  -- standard actions
  local r = {
 {label="Open Door!", callback = function () enterStep(STEP.OPENDOOR) end },
 {label="Inventory", callback=function()
   invWidget = makeInventoryWidget()
  end},
 {label="Quit", callback=unimplemented},
 {label="Buy/Craft", callback=function()craftWidget = makeCraftWidget() end}
 }
  -- item actions
  for k,v in pairs(pg.inventory) do
    if k.usable then
      table.insert(r, { 
  label = {-1, k.spr,15," "..k.usable.name,14," ["..v.."]"},
  callback=function() 
     k.usable.onUse(k) 
					sfx(4,40,15)
   	 refreshCommandWidget()
  end
  })
    end
  end
  return r
end

function makeAnimRaisingString(txt, x, y, c, onEnd)
 return {
    draw=function(self)
   big(txt, x, y-(self.time//2), c)
    end,
    onEnd=onEnd,
    ttl = 40
   }
end

function doFlee()
  log:add({15,"You flee from ",5,game.monster.name,15,"!"})
  enterStep(STEP.OUTDOOR)
end

function doAttack()
 local dmg = rnd(pg.attack)
 damage(game.monster, dmg)
 log:add({15,"You deal ",6,dmg,15," damages to ",5,game.monster.name,15,"!"})
 anims:add(makeAnimRaisingString("-"..dmg, 50, 50, 6, function(self)
   if game.monster.hp <= 0 then
    sfx(2,60,15)
    log:add({15,"You defeated ",6,game.monster.name,15,"!"})
    killMonster()
    enterStep(STEP.LOOT)
   else
    doEnemyTurn()
   end
   for k,v in pairs(game.effects) do
    if v == 1 then
	 game.effects[k] = nil
	else
     game.effects[k] = v-1
	end
   end

 end));
 sfx(1,15,15)
   
end

function isEffectActive(effect)
 return game.effects[effect] ~= nil
end

function addEffect(effect)
  game.effects[effect] = effect.turns;
  log:add({15,"Effect ",9,effect.name,15," started!"})
  ricalcolaPg()
end

function ourTurnActions(action)
  local r = {
   { label = "Attack", callback = doAttack },
   { label = "Flee", callback = doFlee },
  }
  
  --  add combat usable
  -- item actions
  for k,v in pairs(pg.inventory) do
    if k.combat then
      table.insert(r, { 
       label = {-1, k.spr,15," "..k.combat.name,14," ["..v.."]"},
       callback=function() 
         k.combat.onUse(k)
									sfx(5,40,30)

	     refreshCommandWidget()
       end
      })
    end
  end

  return r
end

function doCraft(c)
 for k,v in pairs(c.ingredients) do
   inventoryAdd(k, -v)
 end
 inventoryAdd(c.output, 1)
 log:add({15, "You obtain ", 10, c.output.name})
 refreshCommandWidget()
	sfx(3,40,15)
end

function canCraft(c)
 for k,v in pairs(c.ingredients) do
   local h = pg.inventory[k]
			if not(h and v<=h) then
			  return false
			end 
 end
 return true
end


function potion_healing(item, hp)
     log:add({15, "You drink ",14, item.name, 15, "! ", 6, "+"..hp})
     log:add({15, "  You feel much better now."})
     inventoryAdd(item, -1)
     damage(pg, -hp)
     anims:add(makeAnimRaisingString("+"..hp, 205, 50,6))
   end

function food_healing(item, hp)
   log:add({15, "You eat ",14, item.name, 15, "! ", 6, "+"..hp})
   log:add({15, "  You feel much better now."})
   inventoryAdd(item, -1)
   damage(pg, -hp)
   anims:add(makeAnimRaisingString("+"..hp, 205, 50,6))
end

ITEMS = {
 Hamburger={
  name="Tasty Hamburger",
  spr=314,
  flavour={"The healthy snack","of choice for fine","adventurers.","", "Heal 10 hp."},
  usable={
    name= "Eat",
 onUse=function(item)
	  food_healing(item, 10)
	  addEffect(EFFECTS.MUSCLES)
 end
  }
 },
 Tomato={
  name="Tomato",
  spr=296,
  flavour={"Heal 6 hp."},
  usable={
    name= "Eat",
 onUse=function(item)
	  food_healing(item, 6)
 end
  }
 },
 Cheese={
  name="Cheese",
  spr=317,
  flavour={"Heal 4 hp."},
  usable={
    name= "Eat",
 onUse=function(item)
	  food_healing(item, 4)
 end
  }
 },
 Elixir={
  name="Elixir",
  spr=292,
  flavour={"The strength of","a lion.","", "+10 max hp."},
  usable={
    name= "Drink",
 onUse=function(item)
	  log:add({15, "You drink ",14, item.name, 15, "! You feel stronger!"})
	  anims:add(makeAnimRaisingString("+10 Max!", 190, 50,6))
	  pg.maxHp = pg.maxHp + 10
	  inventoryAdd(item, -1)
	  damage(pg, -10)
 end
  }
 },
 Gold={
  name="Gold",
  spr=264
 },
 Ectoplasm={
  name="Ectoplasm",
  spr=298
 },
 Blood={
  name="Blood",
  spr=265,
  flavour={"It's always good","to bring some","around."},
 },
 Venom={
  name="Venom",
  spr=266,
--  flavour={"It's always good","to bring some","around."},
 },
 Phlogiston={
  name="Phlogiston",
  spr=301,
  flavour={"The heart","of fire."},
 },
 Key={
  name="Key",
  flavour={"They open doors"},
  spr=319
 },
 Pants={
  name="Fancy Panties",
  flavour={"The last in fashon."},
  spr=306,
  equip={
    place= LEGS,
  },
  armour=5
 },
 Shirt={
  name="Shirt",
  flavour={"The last in fashon."},
  spr=295,
  equip={
    place= BODY,
  },
  armour=8  
 },
 Shield={
  name="Shield",
  spr=305,
  equip={
    place= RIGHT,
  },
  armour=40
 },
 Buckler={
  name="Buckler",
  spr=308,
  equip={
    place= RIGHT,
  },
  armour=20
 },
 Armour={
  name="Plate Armour",
  spr=289,
  equip={
    place= BODY,
  },
  armour=20  
 },
 Helm={
  name="Helm",
  spr=309,
  equip={
    place= HEAD,
  },
  armour=15
  
 },
 Cap={
  name="Cap",
  spr=301,
  equip={
    place= HEAD,
  },
  armour=10
  
 },
 Throusers={
  name="Throusers",
  spr=290,
  equip={
    place= LEGS,
  },
  armour=12
  
 },
 Jacket={
  name="Jacket",
  spr=291,
  equip={
    place= BODY,
  },
  armour=15
  
 },
 Mace={
  name="Mace",
  spr=288,
  attack=range(10,40),
  equip={
    place= LEFT,
  },
  
 },
 MintLeaf={
  name="Mint Leaf",
  spr=313,
  flavour={"Always kill with", "a fresh breath"}
 },
 Leather={
  name="Leather",
  spr=297,
  flavour={"Ready to stitch"}
 },
 Rock={
  name="Rock",
  spr=315,
  flavour={"Just a piece of","stone.", "Or is it?"}
 },
 SmokeBomb={
  name="Smoke Bomb",
  spr=311,
  combat={
    name= "Throw",
    onUse=function(item) 
	  addEffect(EFFECTS.SMOKE) 
	  inventoryAdd(item, -1)
	end
  }
 },
 Stick={
  name="Stick",
  spr=307,
  flavour={"Better than bare", "hands."},
  equip={
    place= LEFT,
  },
  attack=range(5,10)
 },
 SwordOfBlast={
  name="Sword of Blast",
  spr=304,
  flavour={"From the guys", "that brought you", "other swords"},
  equip={
    place= LEFT,
  },
  attack=range(20,30)
 },
 Bone={
  name="Bone",
  spr=318,
  flavour={"Hit'em monkey", "style"},
  equip={
    place= LEFT,
  },
  attack=range(4,7)
 },
 Bomb={
  name="Bomb",
  spr=312,
  flavour={"Explosion power!","Batman would","approve.", "","Deals 15 damages."},
  combat={
    name= "Throw",
    onUse=function(item) unimplemented() end
  }
 },
 SmallPotion={
  name="Potion, Small",
  spr=293,
  flavour={"Heal 10 hp."},
  combat={
    name= "Drink",
   onUse=function(item)
     potion_healing(item, 10);
   end
  }
 },
 Weakens={
  name="Weakens",
  spr=299,
  flavour={"Halve monster","strength."},
  combat={
    name= "Throw",
   onUse=function(item)
     log:add({15, "You throw ",14, item.name, 15, "! Monster weakened!"})
	  anims:add(makeAnimRaisingString("Halved!", 50, 50,11))
	  game.monster.attack.min = game.monster.attack.min // 2
	  game.monster.attack.max = game.monster.attack.max // 2
	  inventoryAdd(item, -1)
   end
  }
 },
 EctoDrink={
  name="EctoDrink",
  spr=300,
  flavour={"Makes you ghostly."},
  combat={
    name= "Drink",
   onUse=function(item)
     log:add({15, "You drink ",14, item.name, 15, "! Tastes funny!"})
	  addEffect(EFFECTS.GHOSTLY)	  
	  inventoryAdd(item, -1)
   end
  }
 },
 MediumPotion={
  name="Potion, Medium",
  spr=310,
  flavour={"Heal 20 hp."},
  combat={
    name= "Drink",
   onUse=function(item)
     potion_healing(item, 20);
   end
  }
 },
 BigPotion={
  name="Potion, Big",
  spr=294,
  flavour={"Heal 100 hp."},
  combat={
    name= "Drink",
   onUse=function(item)
     potion_healing(item, 100);
   end
  }
 }
}

EFFECTS = {
	SMOKE = {
		spr = 270,
		name = "SMOKE",
		turns = 4
	},
	GHOSTLY = {
		spr = 271,
		name = "GHOSTLY",
		turns = 8
	},
	MUSCLES = {
		spr = 268,
		name = "MUSCLES",
		turns = 10
	},
}

CRAFTS = {
	{
		ingredients = { [ITEMS.Blood]=10},
		output = ITEMS.Elixir
	},
	{
		ingredients = { [ITEMS.Gold]=10},
		output = ITEMS.SmallPotion
	},
	{
		ingredients = { [ITEMS.Gold]=20},
		output = ITEMS.MediumPotion
	},
	{
		ingredients = { [ITEMS.Venom]=4},
		output = ITEMS.Weakens
	},
	{
		ingredients = { [ITEMS.Ectoplasm]=5, [ITEMS.MintLeaf]=1  },
		output = ITEMS.EctoDrink
	},
	{
		ingredients = { [ITEMS.Gold]=10, [ITEMS.Bone]=12},
		output = ITEMS.Key
	},
	{
		ingredients = { [ITEMS.MintLeaf]=3, [ITEMS.Stick]=1, [ITEMS.Rock]=3},
		output = ITEMS.Shield
	},
	{
		ingredients = { [ITEMS.Leather]=2},
		output = ITEMS.Cap
	},
	{
		ingredients = { [ITEMS.Leather]=3, [ITEMS.Pants]=1},
		output = ITEMS.Throusers
	},
	{
		ingredients = { [ITEMS.Leather]=4, [ITEMS.Shirt]=1},
		output = ITEMS.Jacket
	},
	{
		ingredients = { [ITEMS.Pants]=3, [ITEMS.Shirt]=3},
		output = ITEMS.Gold,
		qty=15
	},
	{
		ingredients = { [ITEMS.Gold]=15},
		output = ITEMS.Key
	}
	
}

function defMon(name, sprite, hp, 
   attack, levels, gold, loot)
return  {
   name = name,
   spr = sprite,
   maxHpRange = hp,
   attack = attack,
   loot = loot,
   levels = levels,
   gold = gold
 }
end

MONSTERS = {
 defMon("MOUSE",324,range(5,8),range(1,3),
	range(0,20), range(1,2),
 {
  { prob=5, item=ITEMS.Cheese, qty=range(1,2) },
  { prob=2, item=ITEMS.Blood, qty=range(2,3) },
 }),
 defMon("SNAKE",388,range(6,10),range(2,3),
	range(0,15), range(2,3),
 {
  { prob=5, item=ITEMS.Leather, qty=range(1,2) },
  { prob=2, item=ITEMS.Blood, qty=range(2,3) },
  { prob=2, item=ITEMS.Venom, qty=range(2,3) },
 }),
 defMon("KOBOLD",328,range(8,14),range(1,5),
	range(0,20), range(4,5),
 {
  { prob=3, item=ITEMS.Pants, qty=1 },
  { prob=3, item=ITEMS.Tomato, qty=range(1,2) },
  { prob=3, item=ITEMS.MintLeaf, qty=range(2,4) },
 }),
 defMon("SKELETON",396,range(9,13),range(3,4),
	range(0,20), range(3,6),
 {
  { prob=3, item=ITEMS.Bone, qty=1 },
  { prob=3, item=ITEMS.Shirt, qty=1 },
 }),
 defMon("SLUG", 384, range(13,16), range(0,3),
	range(10,30), range(1,2),
 {
  { prob=5, item=ITEMS.MediumPotion, qty=1 },
  { prob=5, item=ITEMS.Blood, qty=range(3,6) },
 }),
 defMon("HELLFLY",456,range(8,12),range(3,10),
	range(20,40), range(4,6),
 {
  { prob=3, item=ITEMS.Venom, qty=range(3,4) },
  { prob=3, item=ITEMS.Blood, qty=range(2,4) },
 }),
 defMon("OGRE",320,range(25,30),range(6,8),
	range(25,60), range(7,9),
 {
  { prob=5, item=ITEMS.Buckler, qty=1 },
  { prob=3, item=ITEMS.Leather, qty=range(2,4) },
 }),
 defMon("SKULL",332,range(25,30),range(1,10),
	range(15,30), range(4,7),
 {
  { prob=1, item=ITEMS.Helm, qty=1 },
  { prob=5, item=ITEMS.Gold, qty=range(10,20) },
 }),
 defMon("GOLEM",76,range(50,60),range(15,20),
	range(40,1000), range(10,20),
 {
  { prob=3, item=ITEMS.Rock, qty=range(5,8) },
 }),
 defMon("GHOST",452,range(15,20),range(2,5),
	range(6,1000), range(1,2),
 {
  { prob=5, item=ITEMS.Ectoplasm, qty=range(2,6) },
 }),
 defMon("SUCCUBUS",448,range(40,50),range(8, 12),
	range(30,1000), range(10,12),
 {
  { prob=1, item=ITEMS.Helm, qty=1 },
  { prob=5, item=ITEMS.Gold, qty=range(10,20) },
 }),
 defMon("DRAGON",392,range(100, 150),range(50, 150),
	range(40,1000), range(30,50),
 {
  { prob=1, item=ITEMS.Helm, qty=1 },
  { prob=5, item=ITEMS.Gold, qty=range(10,20) },
 }),
 defMon("ENT",460,range(30, 150),range(10,20),
	range(25,40), range(20,22),
 {
  { prob=1, item=ITEMS.Helm, qty=1 },
  { prob=5, item=ITEMS.Gold, qty=range(10,20) },
 }),
}

STEP = {
  OUTDOOR={
    enter=onOutDoorEnter,
    actions=outDoorActions
  },
  OPENDOOR={
    enter=onOpenDoorEnter,
    actions=openDoorActions,
  },
  OURTURN={
    actions=ourTurnActions
  },
  LOOT={
    actions=lootActions
  }
  
}

pg.inventory = {
 [ITEMS.SmallPotion] = 3,
 [ITEMS.Key] = 50,
 [ITEMS.Blood] = 50,
  [ITEMS.Shirt] = 50,
   [ITEMS.Pants] = 50,
}

enterStep(STEP.OUTDOOR)
ricalcolaPg()
--[[
for y=0,31 do
 for x=0,31 do
  local n = peek(0x6000+y*32+x)
  mset(x,y, n)
 end
end
sync(4,0,true)
]]

-- <TILES>
-- 000:4444444444444444444444444444444444444444444444444444444944444499
-- 001:4444444444444449449999944949944999944444949444444944444449444444
-- 002:4499999999944444444444444444444494444444944444449444444494444444
-- 003:9994444444499994444444994444444444444444444444444444444444444444
-- 004:4444444444444444444444444444444444444444444444444443443344433334
-- 005:4444444444444444444444444444444144444444443444443344111141111000
-- 006:4444444444444444444422441111111144444422444444441111111400000011
-- 007:4444444444444444444444441114444424411144422221144444442111144444
-- 008:4444499949999444994444444444444444444444444444441444444411444444
-- 009:9999994444444999444444444444444444444449444444494444444944444449
-- 010:4444444494444444499999449449949444444999444449494444449444444494
-- 011:4444444444444444444444444444444444444444444444449444444499444444
-- 012:5555555555555555555555555555555555555555555555555555555555555555
-- 013:5555555555555555555555555555555555555555555555555555555555555555
-- 014:5555555555555555555555555555555555555555555555555555555555555555
-- 015:5555555555555555555555555555555555555555555555555555555555555555
-- 016:4444449444444494444444944444494444444444444449444444494444444944
-- 017:4994444444944444449999944444444444443444444434444444344443333433
-- 018:9444444494444444444444444444444444444444444444444444444444444444
-- 019:4444444444444444444144444414444441444444144441114441110044110000
-- 020:4333344133444111444111004411000011100000000000000000000000000000
-- 021:1100000000000000000000000000000000000000000000000000000000000000
-- 022:0000000100000001000000000000000000000000000000000000000000000000
-- 023:1443333411144433001114440000114400000111000000000000000000000000
-- 024:4444444444444444444414444444414444444414111444410011144400001144
-- 025:4444444944444449444444444444444444444444444444444444444444444444
-- 026:4444499444444944499999444444444444434444444344444443444433433334
-- 027:4944444449444444494444444494444444444444449444444494444443933444
-- 028:5555555555555555555555555555555555555555555555555555555555555555
-- 029:5555555555555555555555555555555555555555555555555555555555555555
-- 030:5555555555555555555555555555555555555555555555555555555555555555
-- 031:5555555555555555555555555555555555555555555555555555555555555555
-- 032:4444494444449444444444444444944444449444444494444444944444449433
-- 033:4444434444444344444443443333344443444444434444444344444434334443
-- 034:4444444444414444444444414441111143114110311411003141100034110000
-- 035:4110000011000000100000000000000000000000000000000000000000000000
-- 040:0000011400000011000000010000000000000000000000000000000000000000
-- 041:4444444444441444144444441111144401141134001141130001141300001143
-- 042:4434444444344444443444443333333344444434444444344444443434443343
-- 043:3494444434494444344444443349444444494444444944444449444444494444
-- 044:5555555555555555555555555555555555555555555555555555555555555555
-- 045:5555555555555555555555555555555555555555555555555555555555555555
-- 046:5555555555555555555555555555555555555555555555555555555555555555
-- 047:5555555555555555555555555555555555555555555555555555555555555555
-- 048:4444944444449444444444444444444444444444444444444444444444444444
-- 049:4444413344443331444134414443341144134110444341004433410041441100
-- 050:4110000011000000100000000000000000000000000000000000000000000000
-- 057:0000011400000011000000010000000000000000000000000000000000000000
-- 058:3314444413334444144314441143344401143144001434440014334400114414
-- 059:4449444444494444444444444444444444444444444444444444444444444444
-- 060:5555555555555555555555555555555555555555555555555555555555555555
-- 061:5555555555555555555555555555555555555555555555555555555555555555
-- 062:5555555555555555555555555555555555555555555555555555555555555555
-- 063:5555555555555555555555555555555555555555555555555555555555555555
-- 064:4444444444444444444444444444444444444444444444444444444444444424
-- 065:4444100014441000144110001441000014410000141100001410000014100000
-- 074:0001444400014441000114410000144100001441000011410000014100000141
-- 075:4444444444444444444444442444444444444444444444444444444444444444
-- 077:0000000000000444000444440044444404444444444444044444440044444400
-- 078:0000000044444000444444404444444044444444444404440400044404000444
-- 079:0000000000000000000000000000000000000000400000004000000040000000
-- 080:4444442444444441444444414444441144444414444444444444444444444444
-- 081:1410000044100000411000004100000041000000100000001000000010000000
-- 090:0000014100000144000001140000001400000014000000140000001400000011
-- 091:4244444414244444144444441124444441244444414444444414444434144444
-- 092:00000000000000000000004400000444000044cc00004cc400044c4400044c44
-- 093:044444440044444444000444c4440004c4444440444444444444444444444444
-- 094:4444444444444444444444444444400000000444444444444444444444444444
-- 095:4000000040000000400000000000000044444000444444004444444044444440
-- 096:4444444444441444444414414444444144444441443333414344444143444441
-- 097:1000000010000000100000000000000000000000000000000000000010000000
-- 106:0000000100000001000000010000000100000001000000010000000100000001
-- 107:4414444442114444434144444341444443414444444444444441444444314444
-- 108:00444c4400444444004444440004444400044444000044440000004400000000
-- 109:4440444444444444444044444400444444044444444444440044444400444444
-- 110:4444440444444404444444044444444044444440444444444444444444444444
-- 111:4444444044444440444444404444444044444440444444000044400000000000
-- 112:4344444443444444333313344444344444443444444434444444344433333344
-- 113:1000000010000000100000001000000010000000100000001000000010000000
-- 122:0000000100000001000000010000000100000001000000010000000100000001
-- 123:4444444444444444444444444444444444444444444444444444444444444444
-- 124:000000000000000000000004000000440000004c0000044c0000044400000444
-- 125:004000000004444444444444cc44444444444444444444444444444444444444
-- 126:0004440440000044404444440044444404444444444444440444444404444444
-- 127:0000000000000000440000004440000044440000444400004444400044444000
-- 128:4444444444444444444444444444444444444444444444444444444444444444
-- 129:1000000010000000100000001000000010000000100000001000000010000000
-- 138:0000000100000001000000110000001400000014000000110000000100000001
-- 139:4444444444444444444444444444444444444444444444444444444444444444
-- 140:5555555555555555555555555555555555555555555555555555555555555555
-- 141:5555555555555555555555555555555555555555555555555555555555555555
-- 142:5555555555555555555555555555555555555555555555555555555555555555
-- 143:5555555555555555555555555555555555555555555555555555555555555555
-- 144:4444444444444444444444444444444444444444444444444444444444444444
-- 145:1000000010000000110000004100000041000000110000001000000010000000
-- 154:0000000100000001000000010000000100000001000000010000000100000001
-- 155:4444444443333343444444344444443444444434444444344444333344344444
-- 156:5555555555555555555555555555555555555555555555555555555555555555
-- 157:5555555555555555555555555555555555555555555555555555555555555555
-- 158:5555555555555555555555555555555555555555555555555555555555555555
-- 159:5555555555555555555555555555555555555555555555555555555555555555
-- 160:4444444434333334434444444344444443444444434444443333444444444344
-- 161:1000000010000000100000001000000010000000100000001000000010000000
-- 170:0000000100000001000000010000000100000001000000010000000100000001
-- 171:4434444444344444443444444333333344444344444443444444434444444344
-- 172:5555555555555555555555555555555555555555555555555555555555555555
-- 173:5555555555555555555555555555555555555555555555555555555555555555
-- 174:5555555555555555555555555555555555555555555555555555555555555555
-- 175:5555555555555555555555555555555555555555555555555555555555555555
-- 176:4444434444444344444443443333333444344444443444444434444444344444
-- 177:1000000010000000100000001000000010000000100000001000000010000000
-- 186:0000000100000001000000010000000100000001000000010000000100000001
-- 187:4444444444444344444443444444344444443444444434444444434444444344
-- 188:5555555555555555555555555555555555555555555555555555555555555555
-- 189:5555555555555555555555555555555555555555555555555555555555555555
-- 190:5555555555555555555555555555555555555555555555555555555555555555
-- 191:5555555555555555555555555555555555555555555555555555555555555555
-- 192:5555555555555555555555555555555555555555555555555555555555555555
-- 193:5555555555555555555555555555555555555555555555555555555555555555
-- 194:5555555555555555555555555555555555555555555555555555555555555555
-- 195:5555555555555555555555555555555555555555555555555555555555555555
-- 200:5555555555555555555555555555555555555555555555555555555555555555
-- 201:5555555555555555555555555555555555555555555555555555555555555555
-- 202:5555555555555555555555555555555555555555555555555555555555555555
-- 203:5555555555555555555555555555555555555555555555555555555555555555
-- 208:5555555555555555555555555555555555555555555555555555555555555555
-- 209:5555555555555555555555555555555555555555555555555555555555555555
-- 210:5555555555555555555555555555555555555555555555555555555555555555
-- 211:5555555555555555555555555555555555555555555555555555555555555555
-- 216:5555555555555555555555555555555555555555555555555555555555555555
-- 217:5555555555555555555555555555555555555555555555555555555555555555
-- 218:5555555555555555555555555555555555555555555555555555555555555555
-- 219:5555555555555555555555555555555555555555555555555555555555555555
-- 224:5555555555555555555555555555555555555555555555555555555555555555
-- 225:5555555555555555555555555555555555555555555555555555555555555555
-- 226:5555555555555555555555555555555555555555555555555555555555555555
-- 227:5555555555555555555555555555555555555555555555555555555555555555
-- 232:5555555555555555555555555555555555555555555555555555555555555555
-- 233:5555555555555555555555555555555555555555555555555555555555555555
-- 234:5555555555555555555555555555555555555555555555555555555555555555
-- 235:5555555555555555555555555555555555555555555555555555555555555555
-- 240:5555555555555555555555555555555555555555555555555555555555555555
-- 241:5555555555555555555555555555555555555555555555555555555555555555
-- 242:5555555555555555555555555555555555555555555555555555555555555555
-- 243:5555555555555555555555555555555555555555555555555555555555555555
-- 248:5555555555555555555555555555555555555555555555555555555555555555
-- 249:5555555555555555555555555555555555555555555555555555555555555555
-- 250:5555555555555555555555555555555555555555555555555555555555555555
-- 251:5555555555555555555555555555555555555555555555555555555555555555
-- </TILES>

-- <SPRITES>
-- 000:0000000000333300033333300333333003333330003333000003300003333330
-- 001:0000000000333000000003003333333000033333333333330003333003333000
-- 002:0000000000033300003000000333333333333000333333330333300000033330
-- 003:0000000003300330333333333033330300333300003333000033330000333300
-- 004:0000000003333300033333000333330003303300033033003330333033303330
-- 005:0000003300000333003333330337733303773333337330333773000037730000
-- 006:3300000033300000333330003333333033377733333377730000377300003773
-- 007:00000000066066006cc666606c66666066c66660066666000066600000060000
-- 008:000000000feeee00009999900feeee00f9999000eeeee000099999000f99ee00
-- 009:000600000006600000066000006c660006c66660066666600666666000666600
-- 010:000b0000000bb000000bb00000b5bb000b5bbbb00bbbbbb00bbbbbb000bbbb00
-- 012:6666666666666006666660066006660600006006000000666600066666666666
-- 013:b0b0b0b0b0b0b0b00bb0b0bb0b0bbb0bbb0bbb0bbb0b0b0bb0bb0bb0b0bb0bb0
-- 014:aaaaaaaaa0aa00aaa0a0000aaaa0000aa000000a0000aaaaa00aa00aaaaa00aa
-- 015:bbb00bbbbb0000bbb000000bb0b0b00bb0b0b00bb000000bb000000bb0b0bb0b
-- 016:0000000000eeee000eeeeee00eeeeee00eeeeee000eeee00000ee0000eeeeee0
-- 017:0000000000eee00000000e00eeeeeee0000eeeeeeeeeeeee000eeee00eeee000
-- 018:00000000000eee0000e000000eeeeeeeeeeee000eeeeeeee0eeee000000eeee0
-- 019:000000000ee00ee0eeeeeeeee0eeee0e00eeee0000eeee0000eeee0000eeee00
-- 020:000000000eeeee000eeeee000eeeee000ee0ee000ee0ee00eee0eee0eee0eee0
-- 021:3773000037733000377733303777777337777777037777770037777700033333
-- 022:0000377300033773033377733777773377777330777773007773330033330000
-- 023:0000000000000000000110000011110000111100000110000000000000000000
-- 032:0003330000737370000333000000400000004000000040000000400000004000
-- 033:000000000aa00330a3333333a037730300333300003773000033330000377300
-- 034:0000000000333300004444000040440000404400004044001440044144400444
-- 035:000000000aa00440a4444444a047740400444400004774000044440000477400
-- 036:004444000034430000300300003c630003cccc3003c6cc3003ccc63000333300
-- 037:0044440000344300003003000036630003666630036666300366663000333300
-- 038:0044440000344300033003303666666336666663366666633666666303333330
-- 039:00f00f0000f00f0000ffff000ffffff00ffffcf00ffffcf00ffcfff00ffffff0
-- 040:00000000000b0b000666b6606cc666666c666666666666660666666600666660
-- 041:0004400000444400444144440414414000444400004444000044440004400440
-- 042:0005500000bb55000bbbb5500b0b05500b0b0b500bbbbb500bbbbb500b0b0050
-- 043:004444000034430000300300003bb30003bbbb3003bbbb3003bbbb3000333300
-- 044:0044440000344300003003000035530003555530035555300355553000333300
-- 045:0004400003344440034444443444444434444444700000040000000000000000
-- 046:060060000600606000066060066696660669e966066efe66066efe6000666660
-- 048:f0000000df0000000dd0000000dd0000000dd0d00000dd0000000d400000d044
-- 049:0aaaaaa00a2662a00a2662a00a2662a00a2662a000a66a0000a66a00000aa000
-- 050:0000000000000000effffefefffefffffeffffeafffafffa0ef00fa000000000
-- 051:0000000044000500004404000000400000000400000050400000004400000000
-- 052:0000000000444400047447400444444004444440047447400044440000000000
-- 053:0006600003366770037667773777777737777777700000070000000000000000
-- 054:0044440000344300003003000036630003666630366666633666666303333330
-- 055:0000eee0000e000e022220002222230022222300222233002223330003333000
-- 056:0000fff0000f000f033330003333370033333700333377003337770007777000
-- 057:00000555000555b500555b5505b5b550055b555005b5b5000555500050000000
-- 058:0044440004444440444444446665566699999999119911914444444404444440
-- 059:0000000000000000003333300337333003733333333337333333337303333330
-- 060:0000000000000000003333300339333003933333333339333333339303333330
-- 061:00000000099000009999900099999990eee999999e9eeeee0eeee9e900e9eee0
-- 062:00ff0000ffff0000fff0000000ff0000000ff0000000ffff00000fff00000ff0
-- 063:000000000e000000e0900000909999ff90900909090000090000000000000000
-- 065:0004004400004400440440400044000000404000044000000044000600040006
-- 066:4444000000044404000404440000040400000004000000000006000000060004
-- 067:0000000000000000000000000440000040000000440000004000000040000000
-- 073:0000000000000005000005550005555500555555005555550055555500555555
-- 074:5000000055000000550000005555000055555000555555005555555055555550
-- 076:000000000000000000000000000000000000000f0000000f000000ff00000fff
-- 077:00ffffff0fffffffffffffffffffffffffffffffffffffffffffffffffffffff
-- 078:f0000000ffff0000fffff000ffffff00fffffff0fffffffffffffffff0f0ffff
-- 079:00000000000000000000000000000000000000000000000000000000f0000000
-- 080:0000000000000000000000000000000000000004000000440000044000000400
-- 081:0000400000444400044004400400004440000000000000000444400004004400
-- 082:0600004406004444000040004044400044400000000000000000000000000004
-- 083:0000000040000000040000000440000000400000004400000004000044044000
-- 085:0000000000000000000000000000000000000000000000000000777700777777
-- 086:0000000000000000000000000000000000000000000000007000000077777007
-- 087:0000000000000000000000000000000000000000000000007000000070000000
-- 088:0000000000000000000000000000000000000099000000990000000900000000
-- 089:0055559900055999000099990000992900009999000009999999909999999909
-- 090:5955555099955550999555002990000099900000999000009900000090990000
-- 092:00000fff00000fff00000fff00000fff000fffff00ffffff00ffffff00ffffff
-- 093:ff0000ffff00000fff00000fff00600ffff000fffffffff0fffffff0fffffff0
-- 094:f00000fff00000fff00000ffff0060fffff000ff0fffffff00fffffff0ffffff
-- 095:ff000000ff000000ff000000ffff0000ffffff00fffffff0fffffff0fffffff0
-- 096:0000440000004004000400400004004000044440000000000000000000000000
-- 097:4000040000000400000000440000011100004444000044440004444400044444
-- 098:0000000400000004440000441111144011111110444411404444444044444440
-- 099:0400400004004400044004400040004000440440004444000000000000000000
-- 100:0000000000000000007000070770007707000077770007777000777770077777
-- 101:0777777777777777777777777777777777777777777777777777777777777777
-- 102:7777777777777777777777777777777777777777777777777777777777777777
-- 103:7007000070770000777700007770000077770000777700007777700066777700
-- 105:099999990009999900000999000009990000099900000bbb0000bbbb000bbbbb
-- 106:9999990099999990999999999999099999990090bbb00009bbb00009bbbb0000
-- 107:0000000000000000000000009000000090000000900000009000000000000000
-- 108:00ffffff00ffffff000fffff0000000000000000000000000000000000000000
-- 109:fffffff0ffffffffffffffffff0f0ff0ff0f0ff000000000000000000000000f
-- 110:00fffffffffffffffffffff0fffff0f0000ff0f0000ff00000000000f0ff000f
-- 111:fffffff0ffffff00fffff0000000000000000000000000000000000000000000
-- 112:0000000000000000000000000000000000000044000044000004400000444444
-- 113:0044444400444444004444400444444044444400004440000000440044444400
-- 114:4444444004444440044444400044444400044444004400000440000004444444
-- 115:0000000000000000000000000000000044440000000440000000400044444400
-- 116:7077777770777777707777777777777700007777000000030000000300000000
-- 117:7777777777777777777777777777777733777777337777773000000000000000
-- 118:7777777777777777777777777777777777773777777733700000330000000000
-- 119:76777700777777007777777077a7a77777a7a77000a0a0000000000000000000
-- 120:0000000000000000000000000000000000000000000000000000009900000099
-- 121:00bbbbbb0bbbbbb00bbbb0000bbb00000bbb0000999990009000900099999009
-- 122:bbbbb000bbbbb00000bbb00000bbb00000bbb000999999009000099099999999
-- 124:0000000f0000000f0000000f0000000f00000000000000000000000000000000
-- 125:0000ff0f0ff0ff0fffffffffffffffffffffffff0fffffff0000000000000000
-- 126:f0fff0fffffff0ffffffffffffffffffffffffffffffffff0000000000000000
-- 127:f0000000f0000000f0000000f0000000f0000000f00000000000000000000000
-- 128:0000000000000055000055ff00005fff00005fff00005fff000055ff00000555
-- 129:000000005000000050000000f5000000f55000001f500000ff50000055000000
-- 130:0000000000000000000000000000000000000000000000000000005500000550
-- 131:0000000000555000055ff55055ffff505fffff505f1fff5055fff550055f5500
-- 133:000000000000000b000000bb00000bbb00000bbb0000bbbb0000bbbb0000bbbb
-- 134:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb9bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
-- 135:b0000000bbb00000bbbb00009bbbb00099bbb000bbbbb000bbbbb000bbbbb000
-- 136:0000000000000000000000000000000600000006000000060000000600000006
-- 137:0006666606666666666666666665566666665566666666666666666666666666
-- 138:6666666066666666666666666655666665566666666666666666666666666666
-- 139:0000000060000000660000006600000066000000666000006660000066600000
-- 141:0000000000000000000000ff00000fff0000ff000000fff00000ffff0000ffff
-- 142:0000000000000000fff00000fff00000f0ff0000f0ff0000ffff00000ff00000
-- 143:0000000000000000000000000a00000000a0000000a0000000a0000000a00000
-- 145:0550555500555555005555550055555505555555055555550555555500555555
-- 146:5555550055555000555555005555550055555500555555505555555055555555
-- 147:0055500000000000000000000000000000000000000000000000000050000000
-- 148:0bbbb0000bb5b00000bbbb00000bbb00000bbbb0000bbbb0000bb5b0000bb550
-- 149:0000555b0000bbb50000bbbb0000bbbb0000bbbb00000bbb00000bbb000000bb
-- 150:bb0bbbb6bb000000bb000000bb000000bbb00000bbb00000bbbbb0005bbbbbb0
-- 151:bbbb000060000000060000000066000000600000000000000000000000000000
-- 152:0000000600000006000000060000000600000000000000000000000000000000
-- 153:66666f0f6660000066660000666660f066666660666666660666666606666666
-- 154:0f0f66660000066600000666f0f06666f0666666666666666666666666666660
-- 155:6600000066000000660000006000000060000000000000000000000000000000
-- 156:000000000000000000000000000000000000000000000000000000ff0000000f
-- 157:000000ff00000000000000ff000ff0000ff00000ff00ff0000000ff0000ff000
-- 158:ff00000000000000ff00000000ff0000000ff0000f00ff00ff000ff000000f00
-- 159:00aa0400000440000044f00000f040000ff0f000ff000000f000000000000000
-- 160:00000000000000000000000500000005000000550000005b0000555500055555
-- 161:055bbbbb55bbbbbb5bbbbbbbbbbbbbbbbbbb5555bb5555555555555555555555
-- 162:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb5555bbbb555555555555555555555555
-- 163:55000000b5500000bb550000bbb50000bbb55000bbb500005555000055550000
-- 164:00bbbbb000bbbbb000bbbbb00bb55b00bbbbb500bbbbbb00bbbbbb00bbbbb005
-- 165:000000050000000000b5bbbb0bb5bbbbbbb55bbbbbbbbbbbbbbbbbbb5bbbbbbb
-- 166:bbbbbbbbbbbbbbbb00bb55bbb0055bbbbb00bbbb55b000bbbbb000bbbbbb0005
-- 167:00000000b0000000bb000000bb000000bbb00000bbb00000bbb0000055bb0000
-- 168:0000000000000000000000000000000000000000000000000000000600000006
-- 169:0066666600666666000666660066666600666666066666666666600066666000
-- 170:6666660066666000666600006666660066666666666666666666666666666666
-- 171:0000000000000000000000000000000000000000600000006000000066000000
-- 172:0000000f000000f0000000f000000f000000f0f0000000000000000000000000
-- 173:0000fff0000000000000ff00000000000000f0000000f00f00000ff000000f00
-- 174:fff00000f00000000ff000000000000000f00000f0f000000f0000000f000000
-- 176:0005555500555555005555550005555500055555000000000000000000000000
-- 177:5555555555555555555555555555555555555555055555550000000000000000
-- 178:5555555555555555555555555555555555555555555555550000000000000000
-- 179:5555500055555500555555005555500055555000555500000000000000000000
-- 180:bbb5500bbbbbb0bbbbbbb5bbbbbbb5bbbbbbbbbb0bbbbbbb00bbbbbb000bbbbb
-- 181:55bbb00bb5bb000bbbbb0000bbb00000bbb00000bb000000bb000000bb000000
-- 182:bbbb500bbbb55bbbbbb5bbbbbbb5bbbb0bbbbbbb0bbbbbbb00bbbbbb00000bbb
-- 183:bbbbb000bbbbb000bbbbb000bbbbb000bbbb0000bbb00000bbb00000b0000000
-- 184:0000000600000066000006660000666600006446000664660666446600664666
-- 185:6666000066660000666600006666000066666000646660006466600064666000
-- 186:0666666606666666006666660066666606646466664664666646646666466466
-- 187:6600000066600000666600006666000044666000646660006466600064666000
-- 188:0000000000000000000000000000000000000000000000000000000f000000ff
-- 189:0000ff000000f000000ff0000000000000ff000000f00000f0f00000fff00000
-- 190:0ff0000000ff000000ff000000000000000f0000000ff0000000f00f000fffff
-- 191:00000000000000000000000000000000000000000000000000000000f0000000
-- 193:0000000000000000200000002200000022200000202202222000228822222888
-- 194:0000000000000000000000000000000022220000222022228822002088822002
-- 195:0000000002000000022000002220000020220000000200000002000000200000
-- 197:0000000000000000000000ff00000fff000fffff00ffffff0fffffff0fffffff
-- 198:000000000ffff000fffffff0ffffffffffffffffffffffffffffffffffffffff
-- 199:0000000000000000000000000000000000000000f0000000f0000000f00000f0
-- 200:000000000000000000000000000000000000000f0000000f0000000f0000000f
-- 201:0000000000000000000000000fffff0ffffffffffffffffffffffffffff00fff
-- 202:00000000000000000fff0000ffffff00fffffff0fffffff0f00ffffff00fffff
-- 204:0000000000000bbb0000bbbb0000bbbb000bbbb5000bbb5b000bbb5b000bbb5b
-- 205:bbb0bbbbbbbbbbbbbbbbb555bbbb55bbbbbb5bbbbbbb5bbbbbbb5bbbbbbbbbbb
-- 206:bbb00000bbbbb0005bbbbb00bbbbbbb0bb5bbbbbbb5bbbbbb55bbbbbb5bbbbbb
-- 207:0000000000000000000000000000000000000000b0000000bbb00000bbbb0000
-- 209:0222888800228888002288880022886600228886002288880002288800022888
-- 210:8888222088888822888888828866888288688882888888828888888288888822
-- 211:2020000020200000020000000200000002000000220000002000000000000000
-- 212:000000000000000f00f0000f00f0000ffff0000f00ff000f000ff00f00000ff0
-- 213:ffffff0fffffff00ffffffffffffffffffffffffffffffffffffffffffffffff
-- 214:ffffff0f00ff000f0ffff0ffffffffffffffffffffffffffffffffffffffffff
-- 215:ff0000f0ff0000ffff0000f0ff000f00fff0ff00fffff000fff00000fff00000
-- 216:0000000f0000000f0000000f0000000000000000000000000000dddd0000d000
-- 217:fff00ffffffffff2fffffff2fffff2220002f22200002222ddd0222200dddd22
-- 218:fffffff02ffffff0222ff00022220000222200dd2222ddd02222d00022222d0d
-- 219:000000000000000000000000dddddd00d0000dd0000000d0000000d0dddd00d0
-- 220:00bbbbb500bbbbb5000bbbbb000bbbbb0000bbbb0000bbbb0000000000000000
-- 221:bbbbbbbb5bbbbbbb55bbbbbbbbbbbbbbbbbbbbbbbbbbbbbb0bbbbbbb00044bbb
-- 222:5bbbbbbb5bbbbbbbbbbbbbb5bbbbbbb5bbbbb55bbbbb55bbbbbbbbbbbbb4bb0b
-- 223:5bbbb0005bbbb0005bbbb000bbbbb000bbbbb000bbbb0000bb000000b0000000
-- 224:0000000000000000000220000000222000022222000022220002000200000000
-- 225:0002022800002002000000000000002200002222222222222222222000000000
-- 226:8882222022222000220000002220000022220000222220002002222220002222
-- 227:0000000000000000000020200002222000222000022202002220000020000000
-- 228:000000ff00000000000000000000000000000000000000000000000000000000
-- 229:ffffffffffffffffffffffff0fffffff0fffffff0fffffff0fffffff0fffffff
-- 230:ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
-- 231:fff00000fff00000fff00000fff00000fff00000fff00000fff00000fff00000
-- 232:000d000000d000000dd0000d0d00dddd0d00d0000dd0000000dd00000000dddd
-- 233:00000002000dd0dddddd0dd000000d0000000d000000dd00000dd000ddd00000
-- 234:22222dd02222200d222222000222220002222200022222002222220022222200
-- 235:000000d0d00000d0dd00dd0000ddd00000000000000000000000000000000000
-- 236:0000000000000000000400000000400000000444000040000000000000000000
-- 237:000404bb00004444000444440004244400042244444442440004424400044444
-- 238:bbb4b00044440000444400004244000022440000244444442440000044400000
-- 239:0000000000000000000000000400000040000000000000004000000000000000
-- 240:0000000000000000000000000000000000000000000000000000000200000002
-- 241:0000000000000002000000220000002200222220223332202333220022222000
-- 242:2000022222000000220000002220000002222222002223330002223300000222
-- 243:2000000000000000000000000000000020000000320000003200000022000000
-- 244:00000000000000000000000000000000000000000000000f0000ffff00000fff
-- 245:0fffffff0fffffff0fffffffffffffffffffffffffffffffffffffffffffff00
-- 246:fffffffffffffffffffffffffffffffffffffffffffffff0fffff00000000000
-- 247:fff00000fff00000ff000000ff00000000000000000000000000000000000000
-- 249:0000000000000002000000020000002200002222022222220000222200000000
-- 250:2222220022222000222220002222000022200000220000002000000000000000
-- 252:0000000000000000000000000000000000000000000000000000000000000004
-- 253:0004444400044224000444220044444400444444044414444441144444144444
-- 254:4440000044400000244400004244000044444000444440004411440044414440
-- </SPRITES>

-- <WAVES>
-- 000:00000000ffffffff00000000ffffffff
-- 001:0123456789abcdeffedcba9876543210
-- 002:0123456789abcdef0123456789abcdef
-- 003:0d90aa090760ba4876eca69d3cb4f0e0
-- </WAVES>

-- <SFX>
-- 000:00a000a000a000a000a00090009000900090008000800080007000700070006000600060005000500040003000300030002000200020001000100010224000000000
-- 001:00e000c000b000a00080005000400050006000a000d000b000b000b0001000d000b000b00030004000a00080009000a000c000500010003000600070124000000000
-- 002:00000000000000000000000000000010001000100010002000200020002000300030004000500050006000700080009000a000b000c000d000e000f0210000000000
-- 003:02100260029002a0025002600230027002900270029002c002400290024002300230023002100210022002200220022002300250028002b002d002e0210000000000
-- 004:00000080009000c000d000e000e000d000900020001000b000c000c000b0009000400030000000000000009000b000a0005000c000c0009000500000310000000000
-- 005:0050006000600070008000800080009000900080008000800070007000600040003000300030004000600070009000a000a000b000c000d000e000e0300000000000
-- 006:0440045004600460047004700480048004800480048004a004a004900490048004700460046004400430043004000420042004300430043004200420130000000000
-- </SFX>

-- <PALETTE>
-- 000:140c1c44243430346d4e4a4e99503834d224ff1028757161597dceeab6048595a1449d2cd2aa996dc2cadad45edeeed6
-- </PALETTE>

