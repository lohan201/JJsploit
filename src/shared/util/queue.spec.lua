local Queue = require(script.Parent.queue)


return function()
    describe("queue", function()
        it("should return elements in fifo order", function()
            local q = Queue.new()
            for i = 1, 10, 1 do
                q:enqueue(i)
            end
            for i = 10, 1, -1 do
                expect(q:dequeue(),i) 
            end
            
        end)

        it("should return nil if no elements", function()
            local q = Queue.new()
            q:enqueue("hi")
            expect(q:dequeue(), "hi")
            expect(q:dequeue(), nil)
        end)
    end)
end