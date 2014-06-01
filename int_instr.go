package mutan

import (
	"fmt"
	"strconv"
)

type IntInstr struct {
	Code      Instr
	Constant  interface{}
	ConstRef  string
	Number    int
	Next      *IntInstr
	Target    *IntInstr
	TargetNum *IntInstr
	size      int
	n         int
	variable  Variable
}

func (instr *IntInstr) String() string {
	str := fmt.Sprintf("%-3d %-12v : %v\n", instr.n, instr.Code, instr.Constant)
	if instr.Next != nil {
		str += instr.Next.String()
	}

	return str
}

func NewIntInstr(code Instr, constant string) *IntInstr {
	return &IntInstr{Code: code, Constant: constant}
}

func (instr *IntInstr) setNumbers(i int, gen *CodeGen) {
	var memLoc int
	for _, variable := range gen.locals {
		variable.pos = memLoc

		switch variable.typ {
		case varArrTy:
			for _, cons := range gen.arrayTable[variable.id] {
				cons.Constant = strconv.Itoa(memLoc)
			}
		case varStrTy:
			for _, instr := range gen.stringTable[variable.id] {
				num, _ := strconv.Atoi(instr.Constant.(string))
				instr.Constant = strconv.Itoa(num + memLoc)
				variable.pos = num + memLoc
			}
		default:
			if variable.instr != nil {
				variable.instr.Constant = strconv.Itoa(memLoc)
			}
		}

		memLoc += variable.size
	}

	num := instr
	for num != nil {
		num.n = i

		if len(num.ConstRef) > 0 {
			num.Constant = strconv.Itoa(gen.locals[num.ConstRef].pos)
		}

		if num.Code != intTarget && num.Code != intIgnore {
			switch num.Code {
			case intConst:
				if num.size == 0 {
					panic("NULL")
				}
				i += num.size
			default:
				i++
			}
		}

		num = num.Next
	}

	num = instr
	for num != nil {
		if num.Code == intJump || num.Code == intJumpi {
			// Set the target constant which we couldn't set before hand
			// when the numbers weren't all set.
			if num.TargetNum != nil {
				num.TargetNum.Constant = string(numberToBytes(int32(num.Target.n), 32))
			}
		}

		num = num.Next
	}
}
