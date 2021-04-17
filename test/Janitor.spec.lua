type Dictionary<Value> = {[string]: Value}
type DescribeFunction = (Dictionary<any>?) -> nil

type Expectation = {
	never: {
		to: {
			be: {
				a: (string) -> Expectation,
				an: (string) -> Expectation,
				near: (number, number?) -> Expectation,
				ok: () -> Expectation,
			},

			equal: (any) -> Expectation,
			throw: (string?) -> Expectation,
		},
	},

	to: {
		be: {
			a: (string) -> Expectation,
			an: (string) -> Expectation,
			near: (number, number?) -> Expectation,
			ok: () -> Expectation,
		},

		equal: (any) -> Expectation,
		throw: (string?) -> Expectation,
	},
}

type describe = (string, DescribeFunction) -> nil
type expect = (any) -> Expectation
type it = describe
type describeSKIP = (string) -> nil

return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local RunService = game:GetService("RunService")

	local Janitor = require(script.Parent)
	local Promise = script.Parent.Parent:FindFirstChild("Promise") and require(script.Parent.Parent.Promise)
	local Scheduler = require(script.Parent.Scheduler)

	local BasicClass = {}
	BasicClass.__index = BasicClass

	function BasicClass.new()
		return setmetatable({
			CleanupFunction = nil;
		}, BasicClass)
	end

	function BasicClass:AddCleanupFunction(Function)
		self.CleanupFunction = Function
		return self
	end

	function BasicClass:Destroy()
		local CleanupFunction = self.CleanupFunction
		if CleanupFunction then
			CleanupFunction()
		end

		table.clear(self)
		setmetatable(self, nil)
	end

	-- describe = describe :: describe
	-- expect = expect :: expect
	-- it = it :: it
	-- describeSKIP = describeSKIP :: describeSKIP
	-- itSKIP = itSKIP :: it

	local function Noop(_: any)
	end

	local Success, CheckValue = pcall(function()
		local NewJanitor = Janitor.new()
		local AddPromise = type(NewJanitor.AddPromise)
		NewJanitor:Destroy()
		return AddPromise == "function" and type(Promise) == "table"
	end)

	local IsPromiseSupported = Success and CheckValue
	local PromiseFunction = IsPromiseSupported and Noop or describeSKIP
	local LinkToInstanceFunction = RunService:IsRunning() and it or itSKIP

	describe("Is", function()
		it("should return true iff the passed value is a Janitor", function()
			local NewJanitor = Janitor.new()
			expect(Janitor.Is(NewJanitor)).to.equal(true)
			NewJanitor:Destroy()
		end)

		it("should return false iff the passed value is anything else", function()
			expect(Janitor.Is(Noop)).to.equal(false)
			expect(Janitor.Is({})).to.equal(false)
			expect(Janitor.Is(BasicClass.new())).to.equal(false)
		end)
	end)

	describe("new", function()
		it("should create a new Janitor", function()
			local NewJanitor = Janitor.new()
			expect(NewJanitor).to.be.ok()
			expect(Janitor.Is(NewJanitor)).to.equal(true)
			NewJanitor:Destroy()
		end)
	end)

	describe("Add", function()
		it("should add things", function()
			local NewJanitor = Janitor.new()
			expect(function()
				NewJanitor:Add(Noop, true)
			end).never.to.throw()

			NewJanitor:Destroy()
		end)

		it("should add things with the given index", function()
			local NewJanitor = Janitor.new()
			expect(function()
				NewJanitor:Add(Noop, true, "Function")
			end).never.to.throw()

			expect(NewJanitor:Get("Function")).to.be.a("function")
			NewJanitor:Destroy()
		end)

		it("should overwrite indexes", function()
			local NewJanitor = Janitor.new()
			local WasRemoved = false
			NewJanitor:Add(function()
				WasRemoved = true
			end, true, "Function")

			NewJanitor:Add(Noop, true, "Function")

			expect(WasRemoved).to.equal(true)
			NewJanitor:Destroy()
		end)

		it("should return the passed object", function()
			local NewJanitor = Janitor.new()
			local Part = NewJanitor:Add(Instance.new("Part"), "Destroy")
			expect(typeof(Part)).to.equal("Instance")
			expect(Part.ClassName).to.equal("Part")
			NewJanitor:Destroy()
		end)

		it("should clean up instances, objects, functions, and connections", function()
			local FunctionWasDestroyed = false
			local JanitorWasDestroyed = false
			local BasicClassWasDestroyed = false

			local NewJanitor = Janitor.new()
			local Part = NewJanitor:Add(Instance.new("Part"), "Destroy")
			Part.Parent = ReplicatedStorage

			local Connection = NewJanitor:Add(Part.ChildRemoved:Connect(Noop), "Disconnect")

			NewJanitor:Add(function()
				FunctionWasDestroyed = true
			end, true)

			NewJanitor:Add(Janitor.new(), "Destroy"):Add(function()
				JanitorWasDestroyed = true
			end, true)

			NewJanitor:Add(BasicClass.new(), "Destroy"):AddCleanupFunction(function()
				BasicClassWasDestroyed = true
			end)

			NewJanitor:Destroy()
			expect(Part.Parent).to.equal(nil)
			expect(Connection.Connected).to.equal(false)
			expect(FunctionWasDestroyed).to.equal(true)
			expect(JanitorWasDestroyed).to.equal(true)
			expect(BasicClassWasDestroyed).to.equal(true)
		end)

		it("should clean up everything correctly", function()
			local NewJanitor = Janitor.new()
			local CleanedUp = 0
			local TotalToAdd = 5000

			for Index = 1, TotalToAdd do
				NewJanitor:Add(function()
					CleanedUp += 1
				end, true, Index)
			end

			for Index = TotalToAdd, 1, -1 do
				NewJanitor:Remove(Index)
			end

			NewJanitor:Destroy()
			expect(CleanedUp).to.equal(TotalToAdd)
		end)

		it("should infer types if not given", function()
			local NewJanitor = Janitor.new()
			local Connection = NewJanitor:Add(ReplicatedStorage.AncestryChanged:Connect(Noop))
			NewJanitor:Destroy()
			expect(Connection.Connected).to.equal(false)
		end)
	end)

	describe("AddPromise", function()
		PromiseFunction("AddPromise isn't supported.")

		it("should add a Promise", function()
			local NewJanitor = Janitor.new()
			expect(Promise.is(NewJanitor:AddPromise(Promise.delay(60)))).to.equal(true)
			NewJanitor:Destroy()
		end)

		it("should cancel the Promise when destroyed", function()
			local NewJanitor = Janitor.new()
			local WasCancelled = false

			NewJanitor:AddPromise(Promise.new(function(Resolve, _, OnCancel)
				if OnCancel(function()
					WasCancelled = true
				end) then
					return
				end

				return Promise.delay(60):andThen(Resolve)
			end))

			NewJanitor:Destroy()
			expect(WasCancelled).to.equal(true)
		end)

		it("should not remove any values from the return", function()
			local NewJanitor = Janitor.new()
			local _, Value = NewJanitor:AddPromise(Promise.new(function(Resolve)
				Resolve(true)
			end)):await()

			expect(Value).to.equal(true)
			NewJanitor:Destroy()
		end)

		it("should throw if the passed value isn't a Promise", function()
			local NewJanitor = Janitor.new()
			expect(function()
				NewJanitor:AddPromise(BasicClass.new())
			end).to.throw()

			NewJanitor:Destroy()
		end)
	end)

	describe("Remove", function()
		it("should always return the Janitor", function()
			local NewJanitor = Janitor.new()
			NewJanitor:Add(Noop, true, "Function")

			expect(NewJanitor:Remove("Function")).to.equal(NewJanitor)
			expect(NewJanitor:Remove("Function")).to.equal(NewJanitor)
			NewJanitor:Destroy()
		end)

		it("should always remove the value", function()
			local NewJanitor = Janitor.new()
			local WasRemoved = false

			NewJanitor:Add(function()
				WasRemoved = true
			end, true, "Function")

			NewJanitor:Remove("Function")

			expect(WasRemoved).to.equal(true)
			NewJanitor:Destroy()
		end)

		it("should properly remove values that are already destroyed", function()
			-- credit to OverHash for pointing out this breaking.
			local NewJanitor = Janitor.new()
			local X = 0

			local SubJanitor = Janitor.new()
			SubJanitor:Add(function()
				X += 1
			end, true)

			NewJanitor:Add(SubJanitor, "Destroy")
			SubJanitor:Destroy()
			expect(function()
				NewJanitor:Destroy()
			end).never.to.throw()

			expect(X).to.equal(1)
		end)
	end)

	describe("Get", function()
		it("should return the value iff it exists", function()
			local NewJanitor = Janitor.new()
			NewJanitor:Add(Noop, true, "Function")
			expect(NewJanitor:Get("Function")).to.equal(Noop)
			NewJanitor:Destroy()
		end)

		it("should return void iff the value doesn't exist", function()
			local NewJanitor = Janitor.new()
			expect(NewJanitor:Get("Function")).to.equal(nil)
			NewJanitor:Destroy()
		end)
	end)

	describe("Cleanup", function()
		it("should cleanup everything", function()
			local NewJanitor = Janitor.new()
			local TotalRemoved = 0
			local FunctionsToAdd = 500

			for _ = 1, FunctionsToAdd do
				NewJanitor:Add(function()
					TotalRemoved += 1
				end, true)
			end

			NewJanitor:Cleanup()
			expect(TotalRemoved).to.equal(FunctionsToAdd)

			for _ = 1, FunctionsToAdd do
				NewJanitor:Add(function()
					TotalRemoved += 1
				end, true)
			end

			NewJanitor:Cleanup()
			expect(TotalRemoved).to.equal(FunctionsToAdd * 2)
		end)
	end)

	describe("Destroy", function()
		it("should cleanup everything", function()
			local NewJanitor = Janitor.new()
			local TotalRemoved = 0
			local FunctionsToAdd = 500

			for _ = 1, FunctionsToAdd do
				NewJanitor:Add(function()
					TotalRemoved += 1
				end, true)
			end

			NewJanitor:Destroy()
			expect(TotalRemoved).to.equal(FunctionsToAdd)
		end)

		it("should render the Janitor unusable", function()
			local NewJanitor = Janitor.new()
			NewJanitor:Destroy()
			expect(function()
				NewJanitor:Add(Noop, true)
			end).to.throw()
		end)
	end)

	describe("LinkToInstance", function()
		it("should link to an Instance", function()
			local NewJanitor = Janitor.new()
			local Part = NewJanitor:Add(Instance.new("Part"), "Destroy")
			Part.Parent = ReplicatedStorage

			expect(function()
				NewJanitor:LinkToInstance(Part)
			end).never.to.throw()

			NewJanitor:Destroy()
		end)

		LinkToInstanceFunction("should cleanup once the Instance is destroyed", function()
			local NewJanitor = Janitor.new()
			local WasCleaned = false

			local Part = Instance.new("Part")
			Part.Parent = workspace

			NewJanitor:Add(function()
				WasCleaned = true
			end, true)

			NewJanitor:LinkToInstance(Part)

			--Scheduler.Wait(0.1)
			Part:Destroy()
			Scheduler.Wait(0.1)

			expect(WasCleaned).to.equal(true)
			NewJanitor:Destroy()
			--expect(function()
			--	NewJanitor:Destroy()
			--end).never.to.throw()
		end)

		LinkToInstanceFunction("shouldn't run if the Instance is removed or parented to nil", function()
			local NewJanitor = Janitor.new()
			local Part = Instance.new("Part")
			Part.Parent = ReplicatedStorage

			NewJanitor:Add(Noop, true, "Function")

			NewJanitor:LinkToInstance(Part)

			Part.Parent = nil
			expect(NewJanitor:Get("Function")).to.equal(Noop)
			Part.Parent = ReplicatedStorage
			expect(NewJanitor:Get("Function")).to.equal(Noop)

			Part:Destroy()
			expect(function()
				NewJanitor:Destroy()
			end).never.to.throw()
		end)
	end)

	describe("LinkToInstances", function()
		it("should not be tested", function()
			expect(not not "i should do this later").to.equal(true)
		end)
	end)
end
