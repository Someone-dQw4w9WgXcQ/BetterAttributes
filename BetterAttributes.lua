--!strict

-- ThreadPool dependency: https://github.com/Someone-dQw4w9WgXcQ/Lua-ThreadPool
local thread = require(game:GetService("ReplicatedStorage"):WaitForChild("ThreadPool"))

local BetterAttributes = {}
BetterAttributes.__index = BetterAttributes

local cached = {}

function BetterAttributes.new(instance: Instance)
	local self = cached[instance]
	if self then
		return self
	end

	--New
	local attributes = instance:GetAttributes()
	local connections = {}
	local self = setmetatable({instance = instance, attributes = attributes, connections = connections}, BetterAttributes)
	self.main = instance.AttributeChanged:Connect(function(attribute)
		local value = instance:GetAttribute(attribute)
		attributes[attribute] = value
		for listeningTo, listeners in connections do
			if listeningTo == attribute then
				for _, listener in listeners do
					thread.spawn(listener, value)
				end
			end
		end
	end)
	instance.Destroying:Connect(function()
		self:Destroy()
	end)
	cached[instance] = self
	return self
end

function BetterAttributes:Destroy()
	cached[self.instance] = nil
	self.main:Disconnect()
	
	table.clear(self)
	setmetatable(self, nil)
end

function BetterAttributes:Set(attribute: string, value: any)
	self.instance:SetAttribute(attribute, value)
end

function BetterAttributes:List(): {[string]: any}
	return self.attributes
end

function BetterAttributes:Find(attribute: string): any
	return self.attributes[attribute]
end

function BetterAttributes:Get(attribute: string, errorMessage: string?): any | never
	local value = self.attributes[attribute]
	if value == nil then
		error(errorMessage or "[Attribute] "..attribute.." doesn't exist in "..self.instance:GetFullName())
	end
	return value
end

function BetterAttributes:IfExists(attribute: string, callback: (any) -> ())
	local value = self.attributes[attribute]
	if value ~= nil then
		callback(value)
	end
end

function BetterAttributes:OnChanged(attribute: string, listener: (any) -> ()): (any) -> ()
	local listeners = self.connections[attribute]
	if not listeners then
		listeners = {}
		self.connections[attribute] = listeners
	end
	table.insert(listeners, listener)
	return function()
		local index = table.find(listeners, listener)
		if index then
			table.remove(listeners, index)
		else
			error("Already disconnected!")
		end
	end
end

function BetterAttributes:OnceEquals(attribute: string, equals: any, callback: (any) -> ())
	local value = self.attributes[attribute]
	if value == equals then
		thread.spawn(callback)
	end

	local listeners = self.connections[attribute]
	if not listeners then
		listeners = {}
		self.connections[attribute] = listeners
	end

	local connection: (any) -> ()
	connection = function(value)
		callback(value)

		local index = table.find(listeners, connection)
		if index then
			table.remove(listeners, index)
		else
			error("Already disconnected!")
		end
	end

	table.insert(listeners, connection)
end

return BetterAttributes
