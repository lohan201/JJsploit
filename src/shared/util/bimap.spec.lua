local Bimap = require(script.Parent.bimap)


return function()
    describe("bimap", function()
        it("basic", function()
            local b = Bimap.new()
            for i = 1, 10, 1 do
                b:insert(i, i+1)
            end
            for i = 1, 10, 1 do
                expect(b:get(i), i+1) 
            end
            for i = 1, 10, 1 do
                expect(b:reverse_get(i+1), i)
            end

            b:remove(1)
            b:insert(2, nil)
            expect (b:get(1), nil)
            expect (b:get(2), nil)
            expect (b:reverse_get(1+1), nil)
            expect (b:reverse_get(2+1), nil)
            for i = 3, 10, 1 do
                expect(b:get(i), i+1) 
            end
            for i = 3, 10, 1 do
                expect(b:reverse_get(i+1), i)
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
                expect(b:reverse_get(i+1), i)
            end

            b[1] == nil
            b[2] == nil
            expect (b[1], nil)
            expect (b[2], nil)
            expect (b:reverse_get(1+1), nil)
            expect (b:reverse_get(2+1), nil)
            for i = 3, 10, 1 do
                expect(b[i], i+1) 
            end
            for i = 3, 10, 1 do
                expect(b:reverse_get(i+1), i)
            end
        end)
    end)
end