
// ours
import ulti/[zbag]

// sdk
import structs/[ArrayList]

Firehose: class {

    noses := ArrayList<Nose> new()

    subscribe: func (f: Func (ZBag)) {
        noses add(Nose new(f))
    }

    publish: func (bag: ZBag) {
        for (nose in noses) {
            nose call(bag)
        }
    }

}

Nose: class {

    f: Func (ZBag)

    init: func (=f)

    call: func (bag: ZBag) {
        f(bag)
    }

}

