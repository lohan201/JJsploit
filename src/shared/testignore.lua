type AccountImpl<K> = {
    __index: AccountImpl<K>,
    new: (name: string, balance: number) -> Account<K>,
    deposit: (self: Account<K>, credit: number) -> (),
    withdraw: (self: Account<K>, debit: number) -> (),
}

type Account<K> = typeof(setmetatable({} :: { name: string, balance: number }, {} :: AccountImpl<K>))

local account : Account<any> = {} :: any
account:deposit(100)


-- Only these two annotations are necessary
local Account: AccountImpl = {} :: AccountImpl
Account.__index = Account

-- Using the knowledge of `Account`, we can take in information of the `new` type from `AccountImpl`, so:
-- Account.new :: (name: string, balance: number) -> Account
function Account.new(name, balance) : Account
    local self = {}
    self.name = name
    self.balance = balance

    return setmetatable(self, Account)
end

-- Ditto:
-- Account:deposit :: (self: Account, credit: number) -> ()
function Account:deposit(credit)
    self.balance += credit
end

-- Ditto:
-- Account:withdraw :: (self: Account, debit: number) -> ()
function Account:withdraw(debit)
    self.balance -= debit
end

local account = Account.new("Alexander", 500)


local myAccount = Account.new("Alexander", 500)

myAccount:deposit(100)


return account