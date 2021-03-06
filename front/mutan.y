%{
package frontend

import (
_	"fmt"
)

var Tree *SyntaxTree

// Helper function to turn a tree in to a regular list.
// Especially handy when parsing argument lists
func makeSlice(tree *SyntaxTree) (ret []*SyntaxTree) {
	if tree != nil && tree.Type != EmptyTy {
		ret = append(ret, tree)
		for _, i := range tree.Children {
			ret = append(ret, makeSlice(i)...)
		}
		tree.Children = nil
	} 

	return
}

func makeArgs(tree *SyntaxTree, reverse bool) (ret []*SyntaxTree) {
	l := makeSlice(tree)
	// Quick reverse
	if reverse {
		for i, j := 0, len(l)-1; i < j; i, j = i+1, j-1 {
			l[i], l[j] = l[j], l[i]
		}
	}

	for _, s := range l {
		if s.Type != ArgTy {
			ret = append(ret, s)
		}
	}

	return
}

%}

%union {
	num int
	str string
	tnode *SyntaxTree
    	check bool
}

/* objects */
%token BLOCK TX CONTRACT MSG
/* build ins */
%token ADDR ORIGIN CALLER CALLVAL CALLDATALOAD CALLDATASIZE GASPRICE CALL CALLCODE SIZEOF EXIT CREATE BALANCE SHA3
%token DIFFICULTY PREVHASH TIMESTAMP GASPRICE BLOCKNUM COINBASE GAS ADDRESS BYTE PUSH POP TRANSACT STORE 
%token SUICIDE
/* Ops */
%token ASSIGN EQUAL
/* smts */
%token END_STMT NIL LAMBDA COLON RETURN PUSH POP
/* expr */
%token IF ELSE FOR LEFT_BRACES RIGHT_BRACES LEFT_BRACKET RIGHT_BRACKET ASM LEFT_PAR RIGHT_PAR STOP
%token FOR VAR CONST FUNC FUNC_CALL IMPORT DOT ARRAY COMMA QUOTE PRINT

%token <str> ID NUMBER INLINE_ASM OP DOP STR BOOLEAN CODE oper AND MUL
%type <tnode> program statement_list statement expression assign_expression simple_expression get_variable
%type <tnode> block_funcs contract_funcs tx_funcs msg_funcs
%type <tnode> if_statement op_expression buildins new_variable arguments sep get_id string
%type <tnode> for_statement optional_else_statement ptr opt_arg_def_list opt_list
%type <tnode> deref_ptr opt_lpar opt_rpar
%type <check> optional_type

%%

program
	: statement_list { Tree = $1 }
	;

statement_list
	: statement_list statement { $$ = NewNode(StatementListTy, $1, $2) }
	| /* Empty */ { $$ = NewNode(EmptyTy) }
	;


statement
	: expression { $$ = $1 }
	| if_statement { $$ = $1 }
	| for_statement { $$ = $1 }
	| FUNC ID LEFT_PAR opt_arg_def_list RIGHT_PAR optional_type LEFT_BRACES statement_list RIGHT_BRACES
		{
			$$ = NewNode(FuncDefTy, $8);
			$$.Constant = $2
			$$.HasRet = $6
			$$.ArgList = makeArgs($4, false)
		}
	| IMPORT string { $$ = NewNode(ImportTy); $$.Constant = $2.Constant }
	| LEFT_BRACES statement_list RIGHT_BRACES { $$ = NewNode(ScopeTy, $2) }
	| END_STMT { $$ = NewNode(EmptyTy); }
	;

opt_arg_def_list
	: opt_arg_def_list VAR ID sep { $$ = NewNode(NewVarTy, $1); $$.Constant = $3 }
	| opt_arg_def_list VAR MUL ID sep { $$ = NewNode(NewVarTy, $1); $$.Constant = $4; $$.Ptr = true }
	| /* Empty */ { $$ = nil }
	;


optional_type
    :  VAR { $$ = true }
    | /* Empty */ { $$ = false }
    ;


buildins
	: STOP LEFT_PAR RIGHT_PAR { $$ = NewNode(StopTy) }
	/*| CALL LEFT_PAR arguments RIGHT_PAR { $$ = NewNode(CallTy, $3) }*/
	| CALL LEFT_PAR get_variable COMMA get_variable COMMA get_variable COMMA ptr COMMA ptr RIGHT_PAR
	  {
		  $$ = NewNode(CallTy, $3, $5, $7, $9, $11)
	  }
	| CALLCODE LEFT_PAR get_variable COMMA get_variable COMMA get_variable COMMA ptr COMMA ptr RIGHT_PAR
	  {
		  $$ = NewNode(CallCodeTy, $3, $5, $7, $9, $11)
	  }
	| TRANSACT LEFT_PAR get_variable COMMA get_variable COMMA get_variable COMMA ptr RIGHT_PAR
	  {
		  $$ = NewNode(TransactTy, $3, $5, $7, $9)
	  }
	| CREATE LEFT_PAR get_variable COMMA simple_expression RIGHT_PAR { $$ = NewNode(CreateTy, $3, $5) }
	| SIZEOF LEFT_PAR ID RIGHT_PAR { $$ = NewNode(SizeofTy); $$.Constant = $3 }
	| PUSH LEFT_PAR expression RIGHT_PAR { $$ = NewNode(PushTy, $3) }
	| POP LEFT_PAR RIGHT_PAR { $$ = NewNode(PopTy) }
	| BYTE LEFT_PAR simple_expression COMMA simple_expression RIGHT_PAR { $$ = NewNode(ByteTy, $3, $5) }
	| BALANCE LEFT_PAR get_variable RIGHT_PAR { $$ = NewNode(BalanceTy, $3) }
	| SHA3 LEFT_PAR ptr COMMA simple_expression RIGHT_PAR { $$ = NewNode(Sha3Ty, $3, $5) }
	| SUICIDE LEFT_PAR simple_expression RIGHT_PAR { $$ = NewNode(SuicideTy, $3) }
	| BLOCK DOT block_funcs { $$ = $3 }
	| TX DOT tx_funcs { $$ = $3 }
	| CONTRACT DOT contract_funcs { $$ = $3 }
	| MSG DOT msg_funcs { $$ = $3 }
	| LAMBDA LEFT_BRACKET CODE RIGHT_BRACKET { $$ = NewNode(LambdaTy); $$.Constant = $3 }
	| PRINT LEFT_PAR simple_expression RIGHT_PAR { $$ = NewNode(PrintTy, $3) }
	;

arguments
	: arguments get_variable sep { $$ = NewNode(ArgTy, $1, $2) }
	| /* Empty */ { $$ = NewNode(EmptyTy) }
	;

sep
	: COMMA { $$ = NewNode(EmptyTy) }
	| /* Empty */ { $$ = NewNode(EmptyTy) }
	;


contract_funcs
	: ADDRESS LEFT_PAR RIGHT_PAR { $$ = NewNode(AddressTy) }
	| STORE LEFT_BRACKET expression RIGHT_BRACKET { $$ = NewNode(StoreTy, $3) }
	| STORE LEFT_BRACKET expression RIGHT_BRACKET ASSIGN expression
		{
			node := NewNode(SetStoreTy, $3)
			$$ = NewNode(AssignmentTy, $6, node)
		}
	;

msg_funcs
	: CALLER LEFT_PAR RIGHT_PAR { $$ = NewNode(CallerTy) }
	| CALLDATALOAD LEFT_BRACKET expression RIGHT_BRACKET { $$ = NewNode(CallDataLoadTy, $3) }
	| CALLDATALOAD { $$ = NewNode(CallDataSizeTy) }
	| GAS LEFT_PAR RIGHT_PAR { $$ = NewNode(GasTy) }
	;


block_funcs
	: TIMESTAMP LEFT_PAR RIGHT_PAR { $$ = NewNode(TimestampTy) }
	| DIFFICULTY LEFT_PAR RIGHT_PAR { $$ = NewNode(DiffTy) }
	| PREVHASH LEFT_PAR RIGHT_PAR { $$ = NewNode(PrevHashTy) }
	| BLOCKNUM LEFT_PAR RIGHT_PAR { $$ = NewNode(BlockNumTy) }
	| COINBASE LEFT_PAR RIGHT_PAR { $$ = NewNode(CoinbaseTy) }
	;

tx_funcs
	: ORIGIN LEFT_PAR RIGHT_PAR { $$ = NewNode(OriginTy) }
	| GASPRICE LEFT_PAR RIGHT_PAR { $$ = NewNode(GasPriceTy) }
	| CALLVAL LEFT_PAR RIGHT_PAR { $$ = NewNode(CallValTy) }
	;

if_statement
	: IF simple_expression LEFT_BRACES statement_list RIGHT_BRACES optional_else_statement
		{
			if $6 == nil {
				$$ = NewNode(IfThenTy, $2, $4)
			} else {
				$$ = NewNode(IfThenElseTy, $2, $4, $6)
			}
		}
	;
optional_else_statement
	: ELSE LEFT_BRACES statement_list RIGHT_BRACES
		{
			$$ = $3
		}
	| ELSE IF simple_expression LEFT_BRACES statement_list RIGHT_BRACES optional_else_statement
		{
			if $7 == nil {
				$$ = NewNode(IfThenTy, $3, $5)
			} else {
				$$ = NewNode(IfThenElseTy, $3, $5, $7)
			}
		}
	| /* Empty */ { $$ = nil }
	;

for_statement
	: FOR expression END_STMT expression END_STMT expression LEFT_BRACES statement_list RIGHT_BRACES
		{
			$$ = NewNode(ForThenTy, $2, $4, $6, $8)
		}
	| FOR expression LEFT_BRACES statement_list RIGHT_BRACES
		{
			$$ = NewNode(ForThenTy, $2, $4)
		}
	;

expression
	: assign_expression { $$ = $1 }
	| simple_expression { $$ = $1 }
	| ASM LEFT_BRACES INLINE_ASM RIGHT_BRACES { $$ = NewNode(InlineAsmTy); $$.Constant = $3 }
	| new_variable { $$ = $1 }
	| RETURN simple_expression { $$ = NewNode(ReturnTy, $2) }
	| EXIT simple_expression { $$ = NewNode(ExitTy, $2) }
	| /* Empty */  { $$ = NewNode(EmptyTy) }
	;

opt_list
	: opt_list expression sep { $$ = NewNode(ArgTy, $1, $2);}
	| /* Empty */ { $$ = nil }
	;

assign_expression
	: deref_ptr ASSIGN simple_expression
		{
	      		$$ = NewNode(AssignmentTy, $3, $1)
		}
	| ID ASSIGN simple_expression
		{
			node := NewNode(SetLocalTy)
			node.Constant = $1
			$$ = NewNode(AssignmentTy, $3, node)
		}
	| ID LEFT_BRACKET simple_expression RIGHT_BRACKET ASSIGN simple_expression
		{
			$$ = NewNode(AssignArrayTy, $3, $6); $$.Constant = $1
		}
	| new_variable ASSIGN simple_expression
		{
			node := NewNode(SetLocalTy)
			node.Constant = $1.Constant
			$$ = NewNode(AssignmentTy, $3, $1, node)
		}
	| ID COLON ASSIGN simple_expression
		{
			node := NewNode(SetLocalTy)
			node.Constant = $1
			varNode := NewNode(NewVarTy); varNode.Constant = $1
			$$ = NewNode(AssignmentTy, $4, varNode, node)
		}
	;

new_variable
	: VAR ID
		{
			$$ = NewNode(NewVarTy)
			$$.Constant = $2
		}
	| VAR MUL ID
		{
			$$ = NewNode(NewVarTy)
			$$.Constant = $3
			$$.Ptr = true
		}
	| VAR LEFT_BRACKET NUMBER RIGHT_BRACKET ID
	  	{
			$$ = NewNode(NewArrayTy)
			$$.Size = $3
			$$.Constant = $5
		}
	;

simple_expression
	: get_variable { $$ = $1 }
	| op_expression { $$ = $1 }
	| opt_lpar get_variable opt_rpar { $$ = $2 }
	| opt_lpar op_expression opt_rpar { $$ = $2 }
	| LEFT_BRACES opt_list RIGHT_BRACES
		{
			$$ = NewNode(InitListTy)
			$$.ArgList = makeArgs($2, false)
		}
	| ID LEFT_PAR opt_list RIGHT_PAR
		{
			$$ = NewNode(FuncCallTy, $3)
			$$.Constant = $1
			$$.ArgList = makeArgs($3, false)
		}
	;

op_expression
    /* ++, -- */
	: get_id DOP { $$ = NewNode(OpTy, $1); $$.Constant = $2 } 
    /* Everything else */
	| simple_expression OP simple_expression { $$ = NewNode(OpTy, $1, $3); $$.Constant = $2 }
	| simple_expression AND simple_expression { $$ = NewNode(OpTy, $1, $3); $$.Constant = $2 }
	| simple_expression MUL simple_expression { $$ = NewNode(OpTy, $1, $3); $$.Constant = $2 }
	| OP simple_expression { $$ = NewNode(OpTy, $2); $$.Constant = $1 }
	;

get_variable
	: ptr { $$ = $1 }
	| deref_ptr { $$ = $1 }
	| AND ID { $$ = NewNode(RefTy); $$.Constant = $2 }
	| NUMBER { $$ = NewNode(ConstantTy); $$.Constant = $1 }
	| ID LEFT_BRACKET expression RIGHT_BRACKET { $$ = NewNode(ArrayTy, $3); $$.Constant = $1 }
	| BOOLEAN { $$ = NewNode(BoolTy); $$.Constant = $1 }
	| string { $$ = $1 }
	| buildins { $$ = $1 }
	;

deref_ptr
	: MUL ID { $$ = NewNode(DerefPtrTy); $$.Constant = $2 }
	;

ptr
	: get_id { $$ = $1 }
	| NIL { $$ = NewNode(NilTy) }
	;

get_id
	: ID { $$ = NewNode(IdentifierTy); $$.Constant = $1 }
	;

string 
	: QUOTE STR QUOTE { $$ = NewNode(StringTy); $$.Constant = $2 }
	;

opt_lpar
	: LEFT_PAR { $$ = NewNode(EmptyTy) }
	;

opt_rpar 
	: RIGHT_PAR { $$ = NewNode(EmptyTy) }
    ;
%%

