-- prelude_class_contract_test.lua - the harness Class() must model shared/class.lua.
--
-- The dialogs call DepotSettingsDialog:superClass().onGuiSetupFinished(self) and their
-- siblings, so a Class() that only chains __index leaves those methods unreachable under
-- the harness. Modelled from D:\FS25_Decoded\dataS\scripts_decompiled\shared\class.lua:
--   :13-16  the instance metatable carries __metatable = members and __index = members
--   :17-21  members chain to baseClass through their own metatable
--   :22-24  class() returns members
--   :25-27  superClass() returns baseClass
--   :28-40  isa(other) walks cur:superClass() until nil
-- One stated gap: a hand-written harness base with no superClass() would make the
-- engine's walk error; this model stops the walk at such a base instead (prelude.lua).

local Base = {}
local BaseMt = Class(Base)
local Mid = {}
local MidMt = Class(Mid, Base)
local Leaf = {}
local LeafMt = Class(Leaf, Mid)

local leaf = setmetatable({}, LeafMt)

T.eq("C1 the instance metatable's __index is the class", LeafMt.__index, Leaf)
T.eq("C2 __metatable is the class, so getmetatable(instance) answers the class (class.lua:14)", getmetatable(leaf), Leaf)
T.eq("C3 and the metatable is locked: setmetatable on an instance raises",
     pcall(setmetatable, leaf, {}), false)
T.eq("C4 members chain to the base (class.lua:17-21)", getmetatable(Leaf).__index, Mid)
T.eq("C5 class() returns the class", Leaf:class(), Leaf)
T.eq("C6 superClass() returns the base", Leaf:superClass(), Mid)
T.eq("C7 a root class has no superClass", Base:superClass(), nil)
T.eq("C8 isa walks the chain to a grandparent", Leaf:isa(Base), true)
T.eq("C9 isa is false for an unrelated class", Leaf:isa({}), false)
T.eq("C10 isa is false when asked from the base about the leaf", Base:isa(Leaf), false)

-- A base with no superClass(): the stated gap, and the MessageDialog stub answers it.
local Plain = { name = "plain" }
local Child = {}
Class(Child, Plain)
T.eq("C11 isa stops at a hand-written base instead of erroring", Child:isa({}), false)
T.eq("C12 and still finds that base", Child:isa(Plain), true)
T.eq("C13 the MessageDialog stub answers superClass() with nil, so a dialog's isa walk ends the engine's way",
     MessageDialog.superClass(), nil)
local Dialog = {}
Class(Dialog, MessageDialog)
T.eq("C14 a dialog class derived from the stub finds it through isa", Dialog:isa(MessageDialog), true)
T.eq("C15 and its instance reaches the stub's lifecycle methods through the chain",
     type(setmetatable({}, Class(Dialog, MessageDialog)).onGuiSetupFinished), "function")
