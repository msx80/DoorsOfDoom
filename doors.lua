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
   local s = {-1, CRAFTS[i].output.spr, 15, " = "}

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


function resetPg()
return {
  maxHp = 20,
  hp=2,
  inventory={
  },
  equip={ -- map PLACE, ITEM
  },
  blockedRemainder=0,
  
  -- dati calcolati
  attack = range(2,4), 
  armour = 0,
  
 }
end

 -- dati del giocatore
 pg=resetPg()


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
     spr(4,0,0,-1,1,0,0,12,12)
     if game.monster then
       local m = game.monster
       --printc(m.name,50, 33,7, true)
       print(m.hp.."/"..m.maxHp,60, 90,6, false, 1, true)
    print(m.attack.min.."-"..m.attack.max,10, 90,5, false, 1, true)
       spr(
							 iff(m.spr<0, 0, m.spr), -- handle map sprites
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
     spr(4,0,0,0,1,0,0,12,12)
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
  game.monster = chooseMonster()
  game.monster.attack = deepcopy(game.monster.attackDef)
  game.monster.maxHp = rnd(game.monster.maxHpRange)
  game.monster.hp = game.monster.maxHp
  game.level=game.level+1
		
		if game.monster.spr<0 then
   mapToMonster(0, -game.monster.spr)
		end
		
  log:add({15,"You open the door and find ",5,game.monster.name,15,"!"})
  inventoryAdd(ITEMS.Key, -1)  
end

function resetDoor()
  game.monster = nil
  game.loot = nil
  game.gold = nil
  game.door = false
end

function onOutDoorEnter()
  resetDoor();
  damage(pg,-1)
end

function deadEnter()
  --resetDoor();
		sfx(7,30,200)
  anims:add({
    draw=function(self)
   big("** DEAD **", 115, 50-(self.time//10), 6)
    end,
    onEnd=nil,
    ttl = 180
   });
  --anims:add(makeAnimRaisingString("** DEAD *", 105, 50,6,nil));
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

	 anims:add(makeAnimRaisingString("-"..realdmg, 205, 50,6,afterEnemyAction));
 
end

function afterEnemyAction(self)
   if pg.hp <= 0 then
		log:add({5,game.monster.name,15," defeats you! ", 6, "YOU'RE DEAD!"})
		log:add({15,"You survived ", 9, game.level, 15, " levels!"})
		
		enterStep(STEP.DEAD)
   else
	 enterStep(STEP.OURTURN)
   end
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

function endTurn()
   if isEffectActive(EFFECTS.REGENERATION) then
     log:add({15,"You regenerate ",6,"2",15," hp!"})   
	 damage(pg, -2)
   end
   for k,v in pairs(game.effects) do
    if v == 1 then
	 game.effects[k] = nil
	else
     game.effects[k] = v-1
	end
   end
end

function damageMonster(dmg, funMonsterStillAlive)
 damage(game.monster, dmg)
 anims:add(makeAnimRaisingString("-"..dmg, 50, 50, 6, function(self)
   if game.monster.hp <= 0 then
    sfx(2,60,15)
    log:add({15,"You defeated ",6,game.monster.name,15,"!"})
    killMonster()
	endTurn()
    enterStep(STEP.LOOT)
   else
    funMonsterStillAlive()
   end
 end));
 sfx(1,15,15)
end

function doAttack()
 local dmg = rnd(pg.attack)
 
 log:add({15,"You deal ",6,dmg,15," damages to ",5,game.monster.name,15,"!"})
 damageMonster(dmg, function () 
   doEnemyTurn()
   endTurn()
 end)
   
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

function startNewGame()
 resetDoor()
 resetPg()
 game.effects={}
 game.level=0
 pg.inventory = {
  [ITEMS.SmallPotion] = 3,
  [ITEMS.Key] = 50,
}
enterStep(STEP.OUTDOOR)
end

function deadActions(action)
  local r = {
   { label = "Try again", callback = startNewGame },
  }
  
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
 Bread={
  name="Bread",
  spr=280,
  flavour={"Just a little stale", "", "Heal 5 hp."},
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
  spr=264,
  flavour={"The precious metal","everybody wants."},
 },
 Ectoplasm={
  name="Ectoplasm",
  spr=298,
  flavour={"Gooey and powerful."},
 },
 Blood={
  name="Blood",
  spr=265,
  flavour={"It's always good","to bring some","around."},
 },
 Venom={
  name="Venom",
  spr=266,
  flavour={"Handle with care."},
 },
 Phlogiston={
  name="Phlogiston",
  spr=302,
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
  flavour={"The basic in combat", "protection."},
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
  flavour={"Ready to be", "stitched"}
 },
 Rock={
  name="Rock",
  spr=315,
  flavour={"Just a piece of","stone.", "Or is it?"}
 },
 SmokeBomb={
  name="Smoke Bomb",
  spr=311,
  flavour={"Creates an", "impenetrable fog."},
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
  attack=range(5,6)
 },
 Fork={
  name="Fork",
  spr=281,
  flavour={"Use the fork, luke."},
  equip={
    place= LEFT,
  },
  attack=range(5,8)
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
  flavour={"Batman would","approve.", "","Deals 40 damages."},
  combat={
    name= "Throw",
    onUse=function(item) 
	  inventoryAdd(item, -1)
	  damageMonster(40, function() end)
	  log:add({15, "You throw ",14, item.name, 15, " and deal ",6,"40",15," damage !"})
	end
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
	  game.monster.attack.min = game.monster.attackDef.min // 2
	  game.monster.attack.max = game.monster.attackDef.max // 2
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
 Rejuvenant={
  name="Rejuvenant",
  spr=282,
  flavour={"Keep healing", "for some turns"},
  usable={
    name= "Drink",
   onUse=function(item)
     log:add({15, "You drink ",14, item.name, 15, "! Tastes sweet!"})
	  addEffect(EFFECTS.REGENERATION)	  
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
	REGENERATION = {
		spr = 284,
		name = "REGENERATION",
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
	},
	{
		ingredients = { [ITEMS.Phlogiston]=2, [ITEMS.Ectoplasm]=3 },
		output = ITEMS.Bomb
	}
	
}

function defMon(name, sprite, hp, 
   attack, levels, gold, loot)
return  {
   name = name,
   spr = sprite,
   maxHpRange = hp,
   attackDef = attack,
   loot = loot,
   levels = levels,
   gold = gold
 }
end

MONSTERS = {
 defMon("MOUSE",-1,range(5,8),range(1,3),
	range(0,20), range(1,2),
 {
  { prob=5, item=ITEMS.Cheese, qty=range(1,2) },
  { prob=2, item=ITEMS.Blood, qty=range(2,3) },
 }),
 defMon("SNAKE",-2,range(6,10),range(2,3),
	range(0,15), range(2,3),
 {
  { prob=5, item=ITEMS.Leather, qty=range(1,2) },
  { prob=2, item=ITEMS.Blood, qty=range(2,3) },
  { prob=2, item=ITEMS.Venom, qty=range(2,3) },
 }),
 defMon("KOBOLD",-4,range(8,14),range(1,5),
	range(0,20), range(4,5),
 {
  { prob=3, item=ITEMS.Pants, qty=1 },
  { prob=3, item=ITEMS.Tomato, qty=range(1,2) },
  { prob=3, item=ITEMS.MintLeaf, qty=range(2,4) },
 }),
 defMon("SKELETON",-3,range(9,13),range(3,4),
	range(0,28), range(3,6),
 {
  { prob=3, item=ITEMS.Bone, qty=1 },
  { prob=3, item=ITEMS.Shirt, qty=1 },
 }),
 defMon("GOBLIN",328,range(6,14),range(4,5),
	range(8,30), range(3,6),
 {
  { prob=3, item=ITEMS.Shirt, qty=1 },
  { prob=3, item=ITEMS.Stick, qty=1 },
  { prob=3, item=ITEMS.MintLeaf, qty=range(2,4) },
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
  { prob=3, item=ITEMS.Helm, qty=1 },
  { prob=5, item=ITEMS.Phlogiston, qty=range(4,6) },
 }),
 defMon("FIREIMP",324,range(8,12),range(6,12),
	range(20,60), range(7,8),
 {
  { prob=3, item=ITEMS.Phlogiston, qty=range(3,4) },
  { prob=5, item=ITEMS.Blood, qty=range(3,5) },
 }),
 defMon("EVIL COOK",396,range(25,35),range(5,8),
	range(20,60), range(5,8),
 {
  { prob=6, item=ITEMS.Bread, qty=range(2,3) },
  { prob=4, item=ITEMS.Tomato, qty=range(2,3) },
  { prob=2, item=ITEMS.Cheese, qty=range(2,3) },
  { prob=5, item=ITEMS.Fork, qty=range(2,3) },
 }),
 defMon("SPIDER",388,range(18,25),range(8,12),
	range(30,1000), range(10,12),
 {
  { prob=3, item=ITEMS.Venom, qty=range(4,6) },
  { prob=5, item=ITEMS.Blood, qty=range(4,6) },
 }),
 
 defMon("GOLEM",76,range(50,60),range(15,20),
	range(40,1000), range(10,20),
 {
  { prob=3, item=ITEMS.Rock, qty=range(5,8) },
 }),
 defMon("GHOST",-5,range(15,20),range(2,5),
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
  DEAD={
	enter=deadEnter,
    actions=deadActions
  },
  LOOT={
    actions=lootActions
  }
  
}

pg.inventory = {
 [ITEMS.SmallPotion] = 3,
 [ITEMS.Key] = 50,
 [ITEMS.Venom] = 50,
 [ITEMS.Ectoplasm] = 50,
 [ITEMS.Phlogiston] = 50,
 [ITEMS.MintLeaf] = 50,
 [ITEMS.Bomb] = 50,
 [ITEMS.Rejuvenant] = 20,
--  [ITEMS.Shirt] = 50,
 [ITEMS.Pants] = 50,
 [ITEMS.Stick] = 50,
--  [ITEMS.Phlogiston] = 50,
}

enterStep(STEP.OUTDOOR)
ricalcolaPg()


function mapToSprite(idx, x, y)
 for i=0,31 do
  local n = mget(x+i,y)
		poke(0x4000+i+32*idx,n)
 end
end

function spriteToMap(idx, x, y)
 for i=0,31 do
  local n = peek(0x4000+i+idx*32)
		trace(n)
		mset(i+x,y,n)
 end
end

function monsterToMap(sprIdx, mapIdx)
  local mx = (mapIdx%7)*32
	 local my = (mapIdx//7)*16
  for x=0,3 do
   for y=0,3 do
  	 spriteToMap(sprIdx+x+y*16, mx,my+x+y*4)
   end
  end
end

function mapToMonster(sprIdx, mapIdx)
  local mx = (mapIdx%7)*32
	 local my = (mapIdx//7)*16
  for x=0,3 do
   for y=0,3 do
  	 mapToSprite(sprIdx+x+y*16, mx,my+x+y*4)
   end
  end
end


--monsterToMap(64, 5); sync(5,0,true)

--mapToMonster(200, 43)


-- MONSTERS ON MAP
-- MOUSE 1
-- SNAKE 2
-- SKELETON 3
-- KOBOLD 4
-- GHOST 5


-- <TILES>
-- 000:0000000000000000000006600000660000060000000600000000660000000600
-- 001:0000000000000000000000000000000000000000000000006666000060060006
-- 002:0000000000000000000000000000000000000000000000000000000000006600
-- 003:0000000000000000000000000000000000000000000000000066600006000000
-- 004:4444444444444444444444444444444444444444444444444444444944444499
-- 005:4444444444444449449999944949944999944444949444444944444449444444
-- 006:4499999999944444444444444444444494444444944444449444444494444444
-- 007:9994444444499994444444994444444444444444444444444444444444444444
-- 008:4444444444444444444444444444444444444444444444444443443344433334
-- 009:4444444444444444444444444444444144444444443444443344111141111000
-- 010:4444444444444444444422441111111144444422444444441111111400000011
-- 011:4444444444444444444444441114444424411144422221144444442111144444
-- 012:4444499949999444994444444444444444444444444444441444444411444444
-- 013:9999994444444999444444444444444444444449444444494444444944444449
-- 014:4444444494444444499999449449949444444999444449494444449444444494
-- 015:4444444444444444444444444444444444444444444444449444444499444444
-- 016:0000066000000060000006600066660000000000000000000000000000000060
-- 017:6066000666600060600006666000060000000000000000000000000000000000
-- 018:6006600060060006600600060000660000000000000000000000000000000000
-- 019:6600000066600000600000006666000000000000000000000000000000000600
-- 020:4444449444444494444444944444494444444444444449444444494444444944
-- 021:4994444444944444449999944444444444443444444434444444344443333433
-- 022:9444444494444444444444444444444444444444444444444444444444444444
-- 023:4444444444444444444144444414444441444444144441114441110044110000
-- 024:4333344133444111444111004411000011100000000000000000000000000000
-- 025:1100000000000000000000000000000000000000000000000000000000000000
-- 026:0000000100000001000000000000000000000000000000000000000000000000
-- 027:1443333411144433001114440000114400000111000000000000000000000000
-- 028:4444444444444444444414444444414444444414111444410011144400001144
-- 029:4444444944444449444444444444444444444444444444444444444444444444
-- 030:4444499444444944499999444444444444434444444344444443444433433334
-- 031:4944444449444444494444444494444444444444449444444494444443933444
-- 032:0000066000006600000660060006000600060666000660060000000600000000
-- 033:0000000000000660000006060000060060000600000006000000060000000000
-- 034:0600000066600066606006600060060000600600006006000060066600000000
-- 035:0000060000600600606606006066660060606600606066006060660000000000
-- 036:4444494444449444444444444444944444449444444494444444944444449433
-- 037:4444434444444344444443443333344443444444434444444344444434334443
-- 038:4444444444414444444444414441111143114110311411003141100034110000
-- 039:4110000011000000100000000000000000000000000000000000000000000000
-- 044:0000011400000011000000010000000000000000000000000000000000000000
-- 045:4444444444441444144444441111144401141134001141130001141300001143
-- 046:4434444444344444443444443333333344444434444444344444443434443343
-- 047:3494444434494444344444443349444444494444444944444449444444494444
-- 048:0000000000066660006600000060000000066000000060000000600006666000
-- 049:0000066066600666066606000600060066006666600060006000666660000000
-- 050:0000666060060060000606600006660000666600006606606060000600000000
-- 052:4444944444449444444444444444444444444444444444444444444444444444
-- 053:4444413344443331444134414443341144134110444341004433410041441100
-- 054:4110000011000000100000000000000000000000000000000000000000000000
-- 061:0000011400000011000000010000000000000000000000000000000000000000
-- 062:3314444413334444144314441143344401143144001434440014334400114414
-- 063:4449444444494444444444444444444444444444444444444444444444444444
-- 065:0000000000000000000000ff00000fff000fffff00ffffff0fffffff0fffffff
-- 066:000000000ffff000fffffff0ffffffffffffffffffffffffffffffffffffffff
-- 067:0000000000000000000000000000000000000000f0000000f0000000f00000f0
-- 068:4444444444444444444444444444444444444444444444444444444444444424
-- 069:4444100014441000144110001441000014410000141100001410000014100000
-- 078:0001444400014441000114410000144100001441000011410000014100000141
-- 079:4444444444444444444444442444444444444444444444444444444444444444
-- 080:000000000000000f00f0000f00f0000ffff0000f00ff000f000ff00f00000ff0
-- 081:ffffff0fffffff00ffffffffffffffffffffffffffffffffffffffffffffffff
-- 082:ffffff0f00ff000f0ffff0ffffffffffffffffffffffffffffffffffffffffff
-- 083:ff0000f0ff0000ffff0000f0ff000f00fff0ff00fffff000fff00000fff00000
-- 084:4444442444444441444444414444441144444414444444444444444444444444
-- 085:1410000044100000411000004100000041000000100000001000000010000000
-- 094:0000014100000144000001140000001400000014000000140000001400000011
-- 095:4244444414244444144444441124444441244444414444444414444434144444
-- 096:000000ff00000000000000000000000000000000000000000000000000000000
-- 097:ffffffffffffffffffffffff0fffffff0fffffff0fffffff0fffffff0fffffff
-- 098:ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
-- 099:fff00000fff00000fff00000fff00000fff00000fff00000fff00000fff00000
-- 100:4444444444441444444414414444444144444441443333414344444143444441
-- 101:1000000010000000100000000000000000000000000000000000000010000000
-- 110:0000000100000001000000010000000100000001000000010000000100000001
-- 111:4414444442114444434144444341444443414444444444444441444444314444
-- 112:00000000000000000000000000000000000000000000000f0000ffff00000fff
-- 113:0fffffff0fffffff0fffffffffffffffffffffffffffffffffffffffffffff00
-- 114:fffffffffffffffffffffffffffffffffffffffffffffff0fffff00000000000
-- 115:fff00000fff00000ff000000ff00000000000000000000000000000000000000
-- 116:4344444443444444333313344444344444443444444434444444344433333344
-- 117:1000000010000000100000001000000010000000100000001000000010000000
-- 126:0000000100000001000000010000000100000001000000010000000100000001
-- 127:4444444444444444444444444444444444444444444444444444444444444444
-- 128:0000000000000000000000000000000000000000000000000000000000000066
-- 129:00000000000000000000000000000000000000000066666666666ff666666ff6
-- 130:0000000000000000000000000000000000000000600000006666666066666666
-- 131:0000000000000000000000000000000000000000000000000000000060000000
-- 132:4444444444444444444444444444444444444444444444444444444444444444
-- 133:1000000010000000100000001000000010000000100000001000000010000000
-- 142:0000000100000001000000110000001400000014000000110000000100000001
-- 143:4444444444444444444444444444444444444444444444444444444444444444
-- 144:00000666000066660006666600666666066666660666666666666ff666666ff6
-- 145:6666666666666666666ff666666ff66666666666666666666666666666666666
-- 146:6666666666666666666666666666ff666666ff6666666666666666666ff66666
-- 147:6660000066660000666660006666660066666600666666606666666066666660
-- 148:4444444444444444444444444444444444444444444444444444444444444444
-- 149:1000000010000000110000004100000041000000110000001000000010000000
-- 158:0000000100000001000000010000000100000001000000010000000100000001
-- 159:4444444443333343444444344444443444444434444444344444333344344444
-- 160:6666666666666666666ff666066ff66606666666006666660000006e0000000e
-- 161:6666666666666666666666666666eeee666eeeee6eeeeeeeeee0000eee00000e
-- 162:6ff666666666666666666666ee666666eeeeee66eeeeee06e000eee00000eeee
-- 163:ff666660ff666660666666606666666066666600666660000000000000000000
-- 164:4444444434333334434444444344444443444444434444443333444444444344
-- 165:1000000010000000100000001000000010000000100000001000000010000000
-- 174:0000000100000001000000010000000100000001000000010000000100000001
-- 175:4434444444344444443444444333333344444344444443444444434444444344
-- 176:000000ee000000ee00000eee00000eee00000eee00000eee00000eee000000ee
-- 177:ee00f0eeeee000eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee
-- 178:0f00eeeee00eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee00
-- 179:00000000e0000000e0000000e0000000e0000000e00000000000000000000000
-- 180:4444434444444344444443443333333444344444443444444434444444344444
-- 181:1000000010000000100000001000000010000000100000001000000010000000
-- 190:0000000100000001000000010000000100000001000000010000000100000001
-- 191:4444444444444344444443444444344444443444444434444444434444444344
-- 193:0000000000000444000444440044444404444444444444044444440044444400
-- 194:0000000044444000444444404444444044444444444404440400044404000444
-- 195:0000000000000000000000000000000000000000400000004000000040000000
-- 204:5555555555555555555555555555555555555555555555555555555555555555
-- 205:5555555555555555555555555555555555555555555555555555555555555555
-- 206:5555555555555555555555555555555555555555555555555555555555555555
-- 207:5555555555555555555555555555555555555555555555555555555555555555
-- 208:00000000000000000000004400000444000044cc00004cc400044c4400044c44
-- 209:044444440044444444000444c4440004c4444440444444444444444444444444
-- 210:4444444444444444444444444444400000000444444444444444444444444444
-- 211:4000000040000000400000000000000044444000444444004444444044444440
-- 220:5555555555555555555555555555555555555555555555555555555555555555
-- 221:5555555555555555555555555555555555555555555555555555555555555555
-- 222:5555555555555555555555555555555555555555555555555555555555555555
-- 223:5555555555555555555555555555555555555555555555555555555555555555
-- 224:00444c4400444444004444440004444400044444000044440000004400000000
-- 225:4440444444444444444044444400444444044444444444440044444400444444
-- 226:4444440444444404444444044444444044444440444444444444444444444444
-- 227:4444444044444440444444404444444044444440444444000044400000000000
-- 236:5555555555555555555555555555555555555555555555555555555555555555
-- 237:5555555555555555555555555555555555555555555555555555555555555555
-- 238:5555555555555555555555555555555555555555555555555555555555555555
-- 239:5555555555555555555555555555555555555555555555555555555555555555
-- 240:000000000000000000000004000000440000004c0000044c0000044400000444
-- 241:004000000004444444444444cc44444444444444444444444444444444444444
-- 242:0004440440000044404444440044444404444444444444440444444404444444
-- 243:0000000000000000440000004440000044440000444400004444400044444000
-- 252:5555555555555555555555555555555555555555555555555555555555555555
-- 253:5555555555555555555555555555555555555555555555555555555555555555
-- 254:5555555555555555555555555555555555555555555555555555555555555555
-- 255:5555555555555555555555555555555555555555555555555555555555555555
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
-- 024:0044444004999994049999940049994004999994049999940499999404444444
-- 025:0f0a0a000f0a0a000a0a0a0000aaa000000a0000000a0000000a0000000a0000
-- 026:0044440000344300003003000035e30003555530035e553003555e3000333300
-- 028:5555555555500555555005555000000550000005555005555550055555555555
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
-- 047:00dddd000dddddd0dffddffddddffddd0dddddd000dddd00000dd000000dd000
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
-- 069:0000000000000000000000000000000000600060066000600660066666066666
-- 070:0000000000000000000600000060000000600000066600000666000066660000
-- 071:0000000000000000000000000000000000000000060060000600606000066060
-- 076:00000000000000000000000000000000000000660000066600006666000066ee
-- 077:00066000066660006666666666e6666666e6666666e66f6f6ee666ff66ffffff
-- 078:0060000006000066e6660066e666e6666666ee6666f66666f666f666ffff6666
-- 079:0000000000600000006000006660000066660000ee660000eee600006ee66000
-- 080:0000000000000000000000000000000000000004000000440000044000000400
-- 081:0000400000444400044004400400004440000000000000000444400004004400
-- 082:0600004406004444000040004044400044400000000000000000000000000004
-- 083:0000000040000000040000000440000000400000004400000004000044044000
-- 084:0000000000000000000000000000000600000006000000060000000000000000
-- 085:606666660666666666669966666699666669ee96669effe9669effe96669ee96
-- 086:666660006666660069966660699666609ee96660effe9660effe96609ee96600
-- 087:066696660669e966066efe66066efe6000666660000000000000000000006600
-- 089:0000000000055b5505b555550555555555555555b55595595555955955555555
-- 090:0000000000000000b00000005550000055b0000055550000555b000055550050
-- 091:0000000000000000000000000000000004400000044000004400000040500000
-- 092:000666e600666eef06666ee60666e6ef0666eeef066e6eff0666e6ff066666ff
-- 093:6fffffffffffffffffffffffffffffffff0000ffff00000fff00000fff00600f
-- 094:fffffffffffffffffffffffff0f0fffff00000fff00000fff00000ffff0060ff
-- 095:6ee6600066666600f66e6660f66e6660ff66ee60ff666e60ff666660fff66660
-- 096:0000440000004004000400400004004000044440000000000000000000000000
-- 097:4000040000000400000000440000011100004444000044440004444400044444
-- 098:0000000400000004440000441111144011111110444411404444444044444440
-- 099:0400400004004400044004400040004000440440004444000000000000000000
-- 100:0000000000000000000000000000000000000000000006000000666000006666
-- 101:0666996600666666000666660000666600066666006666660666666666666666
-- 102:6996600066666000666600006666000666666666666666666966666696666666
-- 103:0066660006666660666666606666660066666600666666006666600066660000
-- 104:0000000000000000000000000000000000000000000000040000000000000000
-- 105:0555555505555555000555550000440000444444444044000000440000004400
-- 106:5555000455500044000000400000004044400040004444400000040000004000
-- 107:4000000000000000000000000000000000000000000000000000000000000000
-- 108:06666fff0666ffff006fffff006fffff000fffff0000ffff000000ff00000000
-- 109:fff000fffffffff0fffffff0fffffff0fffffff0ffffffffffffffffff0f0ff0
-- 110:fff000ff0fffffff00fffffff0ffffff00fffffffffffffffffffff0fffff0f0
-- 111:ffff6660fffff660fffff000fffff000fffff000ffff00000000000000000000
-- 112:0000000000000000000000000000000000000044000044000004400000444444
-- 113:0044444400444444004444400444444044444400004440000000440044444400
-- 114:4444444004444440044444400044444400044444004400000440000004444444
-- 115:0000000000000000000000000000000044440000000440000000400044444400
-- 116:0000666600006666000006660000000600000000000000000000000000000000
-- 117:6666666666666666666066666600666600066666000666660066666600696666
-- 118:9666666696666666666666006666666666666666666666666666666900666669
-- 119:6600000000000000000000000000000066000000660000006600000060000000
-- 120:0000000000000000000000000000000000000000000000000000000000000004
-- 121:0000040000044040000400400040004400400004044000040400000044000000
-- 122:0000000000000000000000000000000000000000400000004000000044000000
-- 124:00000000000000000000000f0000000f0000000f0000000f0000000000000000
-- 125:ff0f0ff00000000f0000ff0f0ff0ff0fffffffffffffffffffffffff0fffffff
-- 126:0000f0f0f0f0f00ff0f000fffffff0ffffffffffffffffffffffffffffffffff
-- 127:0000000000000000f0000000f0000000f0000000f0000000f0000000f0000000
-- 128:0000000000000055000055ff00005fff00005fff00005fff000055ff00000555
-- 129:000000005000000050000000f5000000f55000001f500000ff50000055000000
-- 130:0000000000000000000000000000000000000000000000000000005500000550
-- 131:0000000000555000055ff55055ffff505fffff505f1fff5055fff550055f5500
-- 132:0000000000000000000000000000000000022200002202200220002088000022
-- 135:0000000000000000000000000000000000000000002000000202000022002000
-- 136:0000000000000000000000000000000600000006000000060000000600000006
-- 137:0006666606666666666666666665566666665566666666666666666666666666
-- 138:6666666066666666666666666655666665566666666666666666666666666666
-- 139:0000000060000000660000006600000066000000666000006660000066600000
-- 140:00000000000000000000000f000000ff000000ff000000ff000000ff000000ff
-- 141:000000000fffff00fffffff0ffffffffffffffffffffffffffffffffffffffff
-- 142:000000000fffff00fffffff0ffffffffffffffffffffffffffffffffffffffff
-- 145:0550555500555555005555550055555505555555055555550555555500555555
-- 146:5555550055555000555555005555550055555500555555505555555055555555
-- 147:0055500000000000000000000000000000000000000000000000000050000000
-- 148:0000000200000002000000000000000000000000000222000020022202000002
-- 149:0000000020000000220000000220000000220000000222220002222200222000
-- 150:0000000200000022000000200000220000020000222200002222200000022222
-- 151:2000020000000880000000000000000000000000000000000222200020002200
-- 152:0000000600000006000000060000000600000000000000000000000000000000
-- 153:66666f0f6660000066660000666660f066666660666666660666666606666666
-- 154:0f0f66660000066600000666f0f06666f0666666666666666666666666666660
-- 155:6600000066000000660000006000000060000000000000000000000000000000
-- 156:0000000f00000000000000000000000000000000000000000000000000000000
-- 157:ffffffffffffffff00ffffff00ffffff00ffffff00ffcccc00cccccc0ccccccc
-- 158:fffffff0fffff000fff00000fff00000fff00003ccf00000ccc00000cccc0000
-- 159:0000000000000000030000000030000000300000330000000300000000300000
-- 160:00000000000000000000000500000005000000550000005b0000555500055555
-- 161:055bbbbb55bbbbbb5bbbbbbbbbbbbbbbbbbb5555bb5555555555555555555555
-- 162:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb5555bbbb555555555555555555555555
-- 163:55000000b5500000bb550000bbb50000bbb55000bbb500005555000055550000
-- 164:8200000200000000000000000000000000000000000022200002002200200000
-- 165:2220000022000000220000002200000022206006022000002222000022220000
-- 166:0000220000002200000022000000220000022202000222220022222002220000
-- 167:0000020000000020000000880000000022000000022000000002000000022000
-- 168:0000000000000000000000000000000000000000000000000000000600000006
-- 169:0066666600666666000666660066666600666666066666666666600066666000
-- 170:6666660066666000666600006666660066666666666666666666666666666666
-- 171:0000000000000000000000000000000000000000600000006000000066000000
-- 172:0000000000000000000000000000000000000000000000000000000f0000000f
-- 173:0ccc22cc0cccc2cc0ccccccc0ccccccc0cccccccfcccccccfffcffffffffffff
-- 174:22cc00002cccc000ccccc000ccccc000ccccc0cccccc00ccffcffcccffffffcc
-- 175:00330000000300000cc30000ccc33000cccc3000cccc3300ccc00300ccc00000
-- 176:0005555500555555005555550005555500055555000000000000000000000000
-- 177:5555555555555555555555555555555555555555055555550000000000000000
-- 178:5555555555555555555555555555555555555555555555550000000000000000
-- 179:5555500055555500555555005555500055555000555500000000000000000000
-- 180:0220000082000000800000000000000000000000000000000000000000000000
-- 181:0088222200802220008000000008000000000000000000000000000000000000
-- 182:2880000000800000008000000800000000000000000000000000000000000000
-- 183:0000220000000280000000800000000000000000000000000000000000000000
-- 184:0000000600000066000006660000666600006446000664660666446600664666
-- 185:6666000066660000666600006666000066666000646660006466600064666000
-- 186:0666666606666666006666660066666606646466664664666646646666466466
-- 187:6600000066600000666600006666000044666000646660006466600064666000
-- 188:0000000f0000000f000000ff000000ff0000cccc000ccccc000ccccc000ccccc
-- 189:fffffff2fffffff2fffffff2fffffff2cccccff2cccccff2cccccfffccccccff
-- 190:ffffffccf2fffffffffffffff2fffffffffffcccf2fcccccfffcccccffcccccc
-- 191:cc00000000000000000000000000000000000000cc000000cccc0000cccc0000
-- 193:0000000000000000200000002200000022200000202202222000228822222888
-- 194:0000000000000000000000000000000022220000222022228822002088822002
-- 195:0000000002000000022000002220000020220000000200000002000000200000
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
-- 249:0000000000000002000000020000002200002222022222220000222200000000
-- 250:2222220022222000222220002222000022200000220000002000000000000000
-- 252:0000000000000000000000000000000000000000000000000000000000000004
-- 253:0004444400044224000444220044444400444444044414444441144444144444
-- 254:4440000044400000244400004244000044444000444440004411440044414440
-- </SPRITES>

-- <MAP>
-- 000:000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006600000000000000000000000000000000
-- 001:00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000b000000bb00000bbb00000bbb0000bbbb0000bbbb0000bbbb0000000000000000000000ff00000fff0000ff000000fff00000ffff0000ffff00000000000000050000055500055555005555550055555500555555005555550000000000000000000000ff00000fff000fffff00ffffff0fffffff0fffffff00000000000000000000000000000000000000000066666666666ff666666ff600000000000000000000000000000000
-- 002:00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb9bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb0000000000000000fff00000fff00000f0ff0000f0ff0000ffff00000ff000005000000055000000550000005555000055555000555555005555555055555550000000000ffff000fffffff0ffffffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000000060000000666666606666666600000000000000000000000000000000
-- 003:00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000b0000000bbb00000bbbb00009bbbb00099bbb000bbbbb000bbbbb000bbbbb0000000000000000000000000000a00000000a0000000a0000000a0000000a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000f0000000f0000000f00000f0000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000
-- 004:000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000bbbb0000bb5b00000bbbb00000bbb00000bbbb0000bbbb0000bb5b0000bb550000000000000000000000000000000000000000000000000000000ff0000000f0000000000000000000000000000000000000099000000990000000900000000000000000000000f00f0000f00f0000ffff0000f00ff000f000ff00f00000ff000000666000066660006666600666666066666660666666666666ff666666ff600000000000000000000000000000000
-- 005:000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000007777007777770000555b0000bbb50000bbbb0000bbbb0000bbbb00000bbb00000bbb000000bb000000ff00000000000000ff000ff0000ff00000ff00ff0000000ff0000ff0000055559900055999000099990000992900009999000009999999909999999909ffffff0fffffff00ffffffffffffffffffffffffffffffffffffffffffffffff6666666666666666666ff666666ff6666666666666666666666666666666666600000000000000000000000000000000
-- 006:00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000007000000077777007bb0bbbb6bb000000bb000000bb000000bbb00000bbb00000bbbbb0005bbbbbb0ff00000000000000ff00000000ff0000000ff0000f00ff00ff000ff000000f005955555099955550999555002990000099900000999000009900000090990000ffffff0f00ff000f0ffff0ffffffffffffffffffffffffffffffffffffffffff6666666666666666666666666666ff666666ff6666666666666666666ff6666600000000000000000000000000000000
-- 007:00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000007000000070000000bbbb00006000000006000000006600000060000000000000000000000000000000aa0400000440000044f00000f040000ff0f000ff000000f0000000000000000000000000000000000000000000000000000000000000000000000000000000ff0000f0ff0000ffff0000f0ff000f00fff0ff00fffff000fff00000fff00000666000006666000066666000666666006666660066666660666666606666666000000000000000000000000000000000
-- 008:0000000000000000000000000000000000000000000000000000000000000000000000000000000000700007077000770700007777000777700077777007777700bbbbb000bbbbb000bbbbb00bb55b00bbbbb500bbbbbb00bbbbbb00bbbbb0050000000f000000f0000000f000000f000000f0f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ff000000000000000000000000000000000000000000000000000000006666666666666666666ff666066ff66606666666006666660000006e0000000e00000000000000000000000000000000
-- 009:00000000000000000000000000000000000000000000000000000000000000000777777777777777777777777777777777777777777777777777777777777777000000050000000000b5bbbb0bb5bbbbbbb55bbbbbbbbbbbbbbbbbbb5bbbbbbb0000fff0000000000000ff00000000000000f0000000f00f00000ff000000f00099999990009999900000999000009990000099900000bbb0000bbbb000bbbbbffffffffffffffffffffffff0fffffff0fffffff0fffffff0fffffff0fffffff6666666666666666666666666666eeee666eeeee6eeeeeeeeee0000eee00000e00000000000000000000000000000000
-- 010:00000000000000000000000000000000000000000000000000000000000000007777777777777777777777777777777777777777777777777777777777777777bbbbbbbbbbbbbbbb00bb55bbb0055bbbbb00bbbb55b000bbbbb000bbbbbb0005fff00000f00000000ff000000000000000f00000f0f000000f0000000f0000009999990099999990999999999999099999990090bbb00009bbb00009bbbb0000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff6ff666666666666666666666ee666666eeeeee66eeeeee06e000eee00000eeee00000000000000000000000000000000
-- 011:0000000000000000000000000000000000000000000000000000000000000000700700007077000077770000777000007777000077770000777770006677770000000000b0000000bb000000bb000000bbb00000bbb00000bbb0000055bb000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000009000000090000000900000009000000000000000fff00000fff00000fff00000fff00000fff00000fff00000fff00000fff00000ff666660ff66666066666660666666606666660066666000000000000000000000000000000000000000000000000000
-- 012:00000000000000000000000000000000000000000000000000000000000000007077777770777777707777777777777700007777000000030000000300000000bbb5500bbbbbb0bbbbbbb5bbbbbbb5bbbbbbbbbb0bbbbbbb00bbbbbb000bbbbb0000000000000000000000000000000000000000000000000000000f000000ff000000000000000000000000000000000000000000000000000000990000009900000000000000000000000000000000000000000000000f0000ffff00000fff000000ee000000ee00000eee00000eee00000eee00000eee00000eee000000ee00000000000000000000000000000000
-- 013:0000000000000000000000000000000000000000000000000000000000000000777777777777777777777777777777773377777733777777300000000000000055bbb00bb5bb000bbbbb0000bbb00000bbb00000bb000000bb000000bb0000000000ff000000f000000ff0000000000000ff000000f00000f0f00000fff0000000bbbbbb0bbbbbb00bbbb0000bbb00000bbb00009999900090009000999990090fffffff0fffffff0fffffffffffffffffffffffffffffffffffffffffffff00ee00f0eeeee000eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee00000000000000000000000000000000
-- 014:00000000000000000000000000000000000000000000000000000000000000007777777777777777777777777777777777773777777733700000330000000000bbbb500bbbb55bbbbbb5bbbbbbb5bbbb0bbbbbbb0bbbbbbb00bbbbbb00000bbb0ff0000000ff000000ff000000000000000f0000000ff0000000f00f000fffffbbbbb000bbbbb00000bbb00000bbb00000bbb000999999009000099099999999fffffffffffffffffffffffffffffffffffffffffffffff0fffff000000000000f00eeeee00eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee0000000000000000000000000000000000
-- 015:000000000000000000000000000000000000000000000000000000000000000076777700777777007777777077a7a77777a7a77000a0a0000000000000000000bbbbb000bbbbb000bbbbb000bbbbb000bbbb0000bbb00000bbb00000b000000000000000000000000000000000000000000000000000000000000000f00000000000000000000000000000000000000000000000000000000000000000000000fff00000fff00000ff000000ff0000000000000000000000000000000000000000000000e0000000e0000000e0000000e0000000e0000000000000000000000000000000000000000000000000000000
-- 016:000000000000000000000000000000000000000000000000000000000000000044000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 017:000400440000440044044040004400000040400004400000004400060004000600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 018:444400000004440400040444000004040000000400000000000600000006000444000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 019:000000000000000000000000044000004000000044000000400000004000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 020:000000000000000000000000000000000000000400000044000004400000040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 021:000040000044440004000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 022:060000440600444400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 023:000000004000000004000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 024:000044000000400400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 025:400004000000040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 026:000000040000000444000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 027:040040000400440004000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 029:004444440044444400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 030:444444400444444004000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 031:000000000000000000000000000000004444000000044000000040004444440000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 101:000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000007777007777770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 102:000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000070000000777770070000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 103:000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000070000000700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 104:000000000000000000000000000000000000000000000000000000000000000000000000000000000070000707700077070000777700077770007777700777770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 105:000000000000000000000000000000000000000000000000000000000000000007777777777777777777777777777777777777777777777777777777777777770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 106:000000000000000000000000000000000000000000000000000000000000000077777777777777777777777777777777777777777777777777777777777777770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 107:000000000000000000000000000000000000000000000000000000000000000070070000707700007777000077700000777700007777000077777000667777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 108:000000000000000000000000000000000000000000000000000000000000000070777777707777777077777777777777000077770000000300000003000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 109:000000000000000000000000000000000000000000000000000000000000000077777777777777777777777777777777337777773377777730000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 110:000000000000000000000000000000000000000000000000000000000000000077777777777777777777777777777777777737777777337000003300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 111:000000000000000000000000000000000000000000000000000000000000000076777700777777007777777077a7a77777a7a77000a0a00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 113:000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000044400044444004444440444444444444404444444004444440000000000000000000000000000000000
-- 114:000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004444400044444440444444404444444444440444040004440400044400000000000000000000000000000000
-- 115:000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000040000000400000004000000000000000000000000000000000000000
-- 116:00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004400000444000044cc00004cc400044c4400044c4400000000000000000000000000000000
-- 117:000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000044444440044444444000444c4440004c444444044444444444444444444444400000000000000000000000000000000
-- 118:000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000444444444444444444444444444440000000044444444444444444444444444400000000000000000000000000000000
-- 119:000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000400000004000000040000000000000004444400044444400444444404444444000000000000000000000000000000000
-- 120:00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000444c440044444400444444000444440004444400004444000000440000000000000000000000000000000000000000
-- 121:000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000444044444444444444404444440044444404444444444444004444440044444400000000000000000000000000000000
-- 122:000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000444444044444440444444404444444404444444044444444444444444444444400000000000000000000000000000000
-- 123:000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000444444404444444044444440444444404444444044444400004440000000000000000000000000000000000000000000
-- 124:000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004000000440000004c0000044c000004440000044400000000000000000000000000000000
-- 125:000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004000000004444444444444cc4444444444444444444444444444444444444400000000000000000000000000000000
-- 126:000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000444044000004440444444004444440444444444444444044444440444444400000000000000000000000000000000
-- 127:000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000044000000444000004444000044440000444440004444400000000000000000000000000000000000
-- </MAP>

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
-- 007:00d000d000d000d000d000c000c000b000b000a000900080007000700070007000700070008000800080008000800080008000200030002000300020250000000000
-- </SFX>

-- <PALETTE>
-- 000:140c1c44243430346d4e4a4e99503834d224ff1028757161597dceeab6048595a1449d2cd2aa996dc2cadad45edeeed6
-- </PALETTE>

-- <COVER>
-- 000:130100007494648393160f00880077000012ffb0e45445353414055423e2033010000000129f40402000ff00c2000000000f00880078990583ae6b4041c0c1444243ff01820343d6edee6de4a4e4432d422daa99ad4de558591a57171695d7ec00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000080ff001080c1840b0e0c00803162438c0b1a3c782051a4488c05085cb88133a6cd8c1b3a7cf8027088c1942b4a9c398235aac5941f0e2468a0b5ac489f2d06c499d190010b8b3508ece9d3d766c0ab3572f4e964d7ef45a9414a6c10e43aa4d9af4f1e4499807661c2050ca6089975b16e43a5418a0d2a34fca2d3a941860d5b45d2245102214a18bb60c2ed5f8b73e66cab47d1e7dca00eba6599b270c1628683ba1ea8c1f72953b29fd23d9cb4bd22db8d43e24529c7bfa00cbd794f863d7a5478c191896e3e88b83637dea0064e1e7d5890b1c1bb65375e1a291e69d5a07dfef5abca347e5dbbc7433f7eccb97450da81661e288b3630830237671019a517f0ff61b19dc23ddcd9b77956b6eb96af9a3710f74cb0dd9f9eaf1d1e7c7be9d3b354eebdd1020a04c2914fd557415f77dde66c538e0e47251a69f5a6dc1d721a7663d878dd2620e085b527b15945018790ad49b138f06a8a226437da8e267480e1411987a557800288e1198636878d53682eb804a762417681956e2ab769129da1362323923978f16b8ba19810285b12c650509a52550591974d66042a544119865c8856e653934662182f17945214b666853567719474f1e7aadc72dd69715795422526689c6d793469975e26176b96cdb9305c9d21e681d275a1589719629ed96ad4ac7ac53421ae690a38e8938a3a40108f0da983a386bd88ff1549155a292eff951e3777258b96f97e57a44979d066664afa27d1a3099ad05c89aab8ba2180111b76a04196475a9d93bed75ba6ab9a497baa866667ccaa9a8a699ce2b62214576d91be489a14baea5bc7ec580c54fea541f2743fab8fe6db20020afe2976ee805234fde5b4a659b3e67100499d62c7cddb9feebafedb3fa3c9feb8c0b64fee6bc057b3226b9033a6013bcd14aa0f8c05d3c2f2cb0f65cd030962b9c313fbefd67ca63ac1b2cf6a990273b3239c317cb11f9ca2feb142eb3fe0c3ca7bb3f354a6ecf362dde6fc8230d24b4c8faa8447f9e4608d1a145293da472b6368d1239ba195a7f97de75dc86b3513eb6a1f100e50ce57cd30cbd95300b19a6a7b865beaffdc9a00908fdc150e0831ed679af13dd28ff5a8984dd21bfa5ed896580b25bb72ad0550e48720a937e61d6e08f7e48709e9f5418f1e7471407f78b8b2d5bd3e77b4e1925e4b7bec927ea9b9ee97eecbfda3ab1ec4e6d05e0827f2e0ed0fcd99a1979db7e4e5b7be9978efbb4f4d7eeb9e8e1a3aec531fa6bde7cfae6dd046bfb81db5f4d78e2a3afb52ee5870bd4aae20e1b3e7f9e8ffbfe3ed3fb6b9ff74647ddc6eefc11d191d008f028a40040070c1f124e22b043a17f8081045c8dfa968112b140f9280cc0220f08c14b8c20396d1c30e0ccf75c380e1f606d1100d10897972379ce632a005085426833491279638e1cc0680318b3b40670d185b9b06e8ff466f0941a54658faa85d58c6576bd39d0368634104415a2604d12f0f38f1ce1ae09f5f13ee47f488214d898f832700d9021767a7962a5e2d8b4492e548683341257017893cc2a2c0b890425557a487142119a8c829933247a27e2c941bbcd853c73a09a32c34fe154eb8244e224623256cac802153b7353e12968054912c11e3208508456102acc6192f227a47412802906c64197829591208021c81a4c8c925495ac356d25168bca5aa2ff719481de1f5949c0b5031755aca56f279961946eda279ebc26118e8934cad0d62b44d4805235794a4c5e63316fd415ef23889dc0192b629a11b0e131a2ddc66243dd91a4d5e6aad9abcf52f1389173262525023ffb46223fe58a1183a047a8012a6ad3bc903aad8e313284ce7a12bf6c4cd46d03a84056b5637d4d596c124308a05472c2569ff47ec3453901544a4192ab8c57a1841aca459a26ea9364d8452dc894463a4b84a964c805415a7343b9d5e2776bd252a6a9b1daa82416a8f3996023981d243e84de3f64f4241f4a24ac356aec5aea0a28b006cab2a23ea3a8d45aef4af9d7c882da4984840a609055a15fa65544284d41678ac9051dbd95d6a83d6717d88ae65611182ead75c0af4139d452ce5ba8518dfbc935d92935b210fb8d244329c01b94b63a6bc59c8d7559bcc5b798caf5839d9c8a622308715ac62cc25695551903ca5c4101742a50bd7ed4b419a3d72ffe72b2a8b238a96f658a5f922b61bec299ad8810f2c7a6a554a05d83a869aac3d0159613b4ecd45f615b04a79eb96321632e684f9a384a4564e9898ce428794bab5cced3f143dded29f466132ce678810adda96e593b77dade44fbb3a57e645a10cfdefaf79fbd13081f63db4ddfda7133b2087f2c79ea25960874c1c9da44d0890cb447c2bd8db806100c771cc0edfe3830ca53f2a47dc6aedeb958342b0d0c6b4d2201e40fc595c10666da8df2ae5712ab4bac528e62531bf737a0485c603e80311966e2296598d24626551f3bdbc3ecdaf8f886c4104b8f0bdda91bd566741e207273d692eebec8f7c15e92be5baca2231769f8c50ce2bb5fbc711b1d544ffcc245b15dd44cb22ebd997ab92274539d9c02992bb6fdc026e763ae541bdb3b76134e1d4c2b9d5ce669270a78c65e8a476d0d52d549a9dbab86e80c97ba9ab8e21a92d9a54435055cd0effa9af1d6aa84f4504d78ec172a94d6051b1f5384cae31351f2d54555bfd459326a4fa84fcb76ab49ad4defd743c9a7d68ef53ea73a99ed8c6a7dabb5a538a5b50ced334588dffd02bd7a93016c671b59c206e31baf2bbc648e5bf3ce8ec927b5bdece4378b7b43eec3b3428d2ce617e9abdc9d577ab53dee6ea12bfec4de27338d1cb44c735a69360782f91f9d7be77b692ed2fe75b79d1d52538396210807d67f391e3d9863096adac698fa97fd7fe02f5c33e9eff61bda093e71678f7c14e4ee15f4c7acaa1b8b1003ed71c77499ddc5679f7a10ebed0bd678ed7e6c27e5c6e8a1d9bac7fd696089eaf7a04f5faae67cc3e2a3693ddc173873a97e2a6f7719d7dc964c11d99e0d9e6b7b10cc4f643bc15ce174f2e9d66f13aab2a9ce9195b3642bedfed850b7d4cd91bf9d1debfdfb7edf8db7f25db8dad3c6f6b1b70d58f1270711fe1ee88dd32ee57b6b0a33c32f8c3fb32c9cbd1d3dbf879f89639b9da199c7a99ccd8766d8dd3ca002d4be5686a7523aed2fb4fdb738353da7af4ceb1421cacf8e7ae27785f39d009bfbb820449bb7b4fcef7f88b0ef4cd3c8795044f9ee0ea28dcabae0cf5df395a829a2562fb7e9abfcbff903bf6b7dc7bb58cdc71ff3650e71dbdb4ed8d7322a39f12fe361c3af3cfb2bc88bc416e69f510a83adc7ba77e53731f1a271d5753b33eb14624910081a73670a19f34d11a7445e33e035537b2df7e92ff76e4d96f082f3283218e87144718723323c08f61c08c18e085e7308e430815d1236d03443428b52eb2942891d08797ad78f4318e968d7108b77981248348448b214f6748848711ad1b48c48d48e48f48058158258e48548558658758858958a58b58c58d58e58921948168148f58468568668768868968568771300600858c68821871348078a21478321291300a31221400978878a78778e78f31b78f78488d68e68a68888988981c6878827868ff82217884214a1098478678e88688c88398898321a98088c783889780a8088421f783a8d78b78d78c78c78678a88da8ea8398078e681b8521d882b86b8898998f885b8498c987b8bb85212889a8e98f985a89a8f987a88c8aa8878ca8ea8dc88881b8d88f88d684b8cb87982d8b98098cb87d8798fb80c8a78fd82a81e88c86a8588fd87c8ec88e8988598be8198298e88cd8de80f8ce8498198d983884884c86c8ac82885911e81c8588cc89e8209309409509609709809909a09b09c095782b8b58109109658801981d94d09719609c884f8ad8de88b86210b81d8ee89d86f8221901529100300419421134221a00d29c29300619f29e29819539d5802932ff9129db89398d8e194b81d83b8521a29929349321239039e29849139949439639e49f68fb87b83d82293d89985f8a39c192d8d19449321629521a49069439c49d49f495695583f8b19f390d84f8259b59fe86d8729419279829b29054649849269339669b79fc8b59019e79c79189289389489589378f09a68219779039689d89fa8889f699d8a69db89b8359c69621a49b49269679a79e89e99658839559859ab8099d694a9299b89b99d29b49ba9c29c89f990b9b88159a59399299599eb83a9169da9979c991b9eb9b21869d39ee87590d8bb8429a99d49c99999db9fb9dc9989089ad8ec92d93d94d95d96d97d98d99d9ad9639278dd9659b98ed96b82ebf90e9fd91e94e93e96e99e9fd9bd9ce9de9ee9fe90f91f92f93f94f95f9a09a19309be87690d9b68e79ed9e09621f03800300af222130a40a50a60af0380a50aa89c098f91996994997999697c9692e392c94995b84c941aa692e94c9e6912ace8d1990aa0a60a80a72ab0a32190ae0ab091a96a94596a99b81494594b9599c985d8049a3a8a96b923a1d9c698b9329f3a82a50a20a30a90a70aa2a82a7d8f49b692a9c3a63aa3a75905abd825a7216c9b3af4a75a93a24ac4a1d97b9359ca884ab4a74a94ab2a84a70a1891c907951a2f8959f1906a91a41ae6ae5a3c903a61a35a1497c920a46aa0a94aa4ac2acf9dc9d2a6f958a68a78ad5810100b3
-- </COVER>

