local fmt = string.format;

local enums = {
	new = function(this, constants)
		local self = setmetatable( {}, this );

		self.constants = constants;
		self.stack = setmetatable({}, {
			__newindex = function(s, k, v)  
				if k > self.top then
					self.top = k;
				end
				rawset(s, k, v)
			end;
		});
		self.new = nil;
		self.pc = 0;
		self.top = -1;
		self.env = getfenv();

		return self;
	end,
	LOADNIL = function(self, instruction)
		for i = instruction[1], instruction[2] do
			print(fmt("setting %d to nil in the stack", i));
			self.stack[i] = nil;
		end
	end,
	LOADK = function(self, instruction)
		-- loads constant Bx into register R(A)
		self.stack[instruction[1]] = self.constants[instruction[2]];
		print(fmt("adding %s to %d in the stack", self.stack[instruction[1]], instruction[1]));
	end,
	LOADBOOL = function(self, instruction)
		-- loads bool into R(A)
		-- true if R(B) == 1
		-- if R(C) != 0 then pc++
		self.stack[instruction[1]] = instruction[2] == 1;
		print(fmt("adding %s to %d in the stack", tostring(self.stack[instruction[1]]), tostring(instruction[1])));
		if instruction[3] ~= 0 then
			self.pc = self.pc + 1;
		end
	end,
	GETGLOBAL = function(self, instruction)
		-- loads Gbl[Kst[Bx]] into Stack[R(A)];
		self.stack[instruction[1]] = self.env[self.constants[instruction[2]]];
		print(fmt("adding the function `%s` to stack %d", self.constants[instruction[2]], instruction[1]))
	end,
	SETGLOBAL = function(self, instruction)
		self.env[self.constants[instruction[2]]] = self.stack[instruction[1]];
		print(fmt("setting global `%s` to `%s`", self.constants[instruction[2]], (instruction[1])));
	end,
	CALL = function(self, instruction)
		local params, results = {};

		if instruction[2] ~= 1 then
			for i = instruction[1] + 1, instruction[2] ~= 0 and instruction[1] + instruction[2] - 1 or self.top do
				table.insert(params, self.stack[i]);
			end
			results = {self.stack[instruction[1]](unpack(params))};
		else
			results = {self.stack[instruction[1]]()};
		end

		print(fmt("calling function with %d paramerters", #params));
		self.top = instruction[1] - 1;

		if instruction[3] ~= 1 then
			local edx = 0;
			for i = instruction[1], instruction[3] ~= 0 and instruction[1] + instruction[3] - 2 or (instruction[2] ~= 0 and instruction[1] + instruction[2] - 1 or self.top) + instruction[1] - 1 do
				edx = edx + 1;
				self.stack[i] = results[edx];
			end
		end
	end,

	RETURN = function(self)
		return "BREAK";
	end
}
enums.__index = enums;

local function wrap(constants, instructions)
	local constants = constants or {};
	local instructions = instructions or {};

	return function(...)

		-- Gbl - ENV
		-- Kst - Constant

		local self = enums:new(constants);

		while true do
			self.pc = self.pc + 1;

			local instruction = instructions[self.pc];
			local enum = instruction[1];
			table.remove(instruction, 1);

			if self[enum] then
				local result = self[enum](self, instruction);

				if result == "BREAK" then
					break;
				end
			end

		end
	end
end

--[[

wrap(
	{"print", "hello"},
	{
		{ -- GETGLOBAL
			"GETGLOBAL",
			0,
			1
		},
		{ -- LOADK
			"LOADK",
			1,
			2
		},
		{ -- LOADBOOL
			"LOADBOOL",
			2,
			1, -- is true?
			0 -- skip next instruction?
		},
		{ -- CALL
			"CALL",
			-- A is reference to function to call
			-- if B is 1 then no parameters
			-- if B != 1 then # of parameters = B - 1
			-- if B is 0 then VARARG to top of stack from A + 1
			0, -- ref
			3, -- params
			0, -- C IS RESULTS / not added yet
		},
		{ -- RETURN
			"RETURN",
		}
	},
{})();

]]

local bytecode = string.dump( function() a = false print(a) end );
local bytecode_meaning = require("GetMeaning")(bytecode);
--table.foreach(bytecode_meaning, print)
local const, instr = bytecode_meaning.Const, bytecode_meaning.Instr;

local enum_names = {
	"LOADK", "LOADBOOL", "LOADNIL", "GETUPVAL", "GETGLOBAL", "GETTABLE", "SETGLOBAL", "SETUPVAL",
	"SETTABLE", "NEWTABLE", "SELF", "ADD", "SUB", "MUL", "DIV", "MOD", "POW", "UNM", "NOT", "LEN",
	"CONCAT", "JMP", "EQ", "LT", "LE", "TEST", "TESTSET", "CALL", "TAILCALL", "RETURN", "FORLOOP",
	"FORPREP", "TFORLOOP", "SETLIST", "CLOSE", "CLOSURE", "VARARG"
}; enum_names[0] = "MOVE";

table.foreach(instr, function(_, instruction) 
	table.insert(instruction, 1, enum_names[instruction.Enum]);
	instruction.Enum, instruction.Value = nil, nil;
end);

wrap(const, instr)();