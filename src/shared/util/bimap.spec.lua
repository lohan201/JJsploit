local Bimap = require(script.Parent.bimap)


return function()
    describe("bimap", function()
        it("basic", function()
            local b = Bimap.new()
            for i = 1, 10, 1 do
                b:insert(i, i+1)
            end
            for i = 1, 10, 1 do
                expect(b:lookup(i), i+1) 
            end
            for i = 1, 10, 1 do
                expect(b:lookupR(i+1), i)
            end

            b:delete(1)
            b:insert(2, nil)
            expect (b:lookup(1), nil)
            expect (b:lookup(2), nil)
            expect (b:lookupR(1+1), nil)
            expect (b:lookupR(2+1), nil)
            for i = 3, 10, 1 do
                expect(b:lookup(i), i+1) 
            end
            for i = 3, 10, 1 do
                expect(b:lookupR(i+1), i)
            end
        end)
        it("index methods", function()
            local b = Bimap.new()
            for i = 1, 10, 1 do
                b[i] = i+1
            end
            for i = 1, 10, 1 do
                expect(b[i], i+1) 
            end
            for i = 1, 10, 1 do
                expect(b:lookupR(i+1), i)
            end

            b[1] = nil
            b[2] = nil
            expect (b[1], nil)
            expect (b[2], nil)
            expect (b:lookupR(1+1), nil)
            expect (b:lookupR(2+1), nil)
            for i = 3, 10, 1 do
                expect(b[i], i+1) 
            end
            for i = 3, 10, 1 do
                expect(b:lookupR(i+1), i)
            end
        end)
    end)
end