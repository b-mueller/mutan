%{
package mutan

import (
	_"fmt"
)

var Tree *SyntaxTree

%}

%union {
	num int
	str string
	tnode *SyntaxTree
    check bool
}

%token ASSIGN EQUAL IF ELSE FOR LEFT_BRACES RIGHT_BRACES STORE LEFT_BRACKET RIGHT_BRACKET ASM LEFT_PAR RIGHT_PAR STOP
%token ADDR ORIGIN CALLER CALLVAL CALLDATALOAD CALLDATASIZE GASPRICE DOT THIS ARRAY CALL COMMA SIZEOF QUOTE
%token END_STMT RETURN CREATE TRANSACT NIL BALANCE VAR_ASSIGN LAMBDA COLON ADDRESS
%token DIFFICULTY PREVHASH TIMESTAMP GASPRICE BLOCKNUM COINBASE GAS FOR VAR FUNC FUNC_CALL
%token <str> ID NUMBER INLINE_ASM OP DOP TYPE STR BOOLEAN CODE
%type <tnode> program statement_list statement expression assign_expression simple_expression get_variable
%type <tnode> if_statement op_expression buildins closure_funcs new_var new_array arguments sep get_id string
%type <tnode> for_statement optional_else_statement ptr sub_expression
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
	| LAMBDA LEFT_BRACKET CODE RIGHT_BRACKET { $$ = NewNode(LambdaTy); $$.Constant = $3 }
	| if_statement { $$ = $1 }
	| for_statement { $$ = $1 }
    | FUNC ID LEFT_PAR RIGHT_PAR LEFT_BRACES statement_list RIGHT_BRACES { $$ = NewNode(FuncDefTy, $6); $$.Constant = $2 }
    | FUNC ID LEFT_PAR RIGHT_PAR optional_type LEFT_BRACES statement_list RIGHT_BRACES {
        $$ = NewNode(FuncDefTy, $7);
        $$.Constant = $2
        $$.HasRet = $5
      }
	| ASM LEFT_PAR INLINE_ASM RIGHT_PAR { $$ = NewNode(InlineAsmTy); $$.Constant = $3 }
    | ID LEFT_PAR RIGHT_PAR { $$ = NewNode(FuncCallTy); $$.Constant = $1 }
	| END_STMT { $$ = NewNode(EmptyTy); }
	;

optional_type
    :  TYPE { $$ = true }
    | /* Empty */ { $$ = false }
    ;

buildins
	: STOP LEFT_PAR RIGHT_PAR { $$ = NewNode(StopTy) }
	/*| CALL LEFT_PAR arguments RIGHT_PAR { $$ = NewNode(CallTy, $3) }*/
	| CALL LEFT_PAR get_variable COMMA get_variable COMMA get_variable COMMA ptr COMMA ptr RIGHT_PAR
	  {
		  $$ = NewNode(CallTy, $3, $5, $7, $9, $11)
	  }
	| TRANSACT LEFT_PAR get_variable COMMA get_variable COMMA ptr RIGHT_PAR
	  {
	  	  $$ = NewNode(TransactTy, $3, $5, $7)
          }
	| CREATE LEFT_PAR get_variable COMMA ptr RIGHT_PAR { $$ = NewNode(CreateTy, $3, $5) }
	| SIZEOF LEFT_PAR ID RIGHT_PAR { $$ = NewNode(SizeofTy); $$.Constant = $3 }
	| THIS DOT closure_funcs { $$ = $3 }
	;

arguments
	: arguments get_variable sep { $$ = NewNode(ArgTy, $1, $2) }
	| /* Empty */ { $$ = NewNode(EmptyTy) }
	;

sep
	: COMMA { $$ = NewNode(EmptyTy) }
	| /* Empty */ { $$ = NewNode(EmptyTy) }
	;

closure_funcs
	: ORIGIN LEFT_PAR RIGHT_PAR { $$ = NewNode(OriginTy) }
	| ADDRESS LEFT_PAR RIGHT_PAR { $$ = NewNode(AddressTy) }
	| CALLER LEFT_PAR RIGHT_PAR { $$ = NewNode(CallerTy) }
	| CALLVAL LEFT_PAR RIGHT_PAR { $$ = NewNode(CallValTy) }
	| CALLDATALOAD LEFT_BRACKET expression RIGHT_BRACKET { $$ = NewNode(CallDataLoadTy, $3) }
	| CALLDATASIZE LEFT_PAR RIGHT_PAR { $$ = NewNode(CallDataSizeTy) }
	| DIFFICULTY LEFT_PAR RIGHT_PAR { $$ = NewNode(DiffTy) }
	| PREVHASH LEFT_PAR RIGHT_PAR { $$ = NewNode(PrevHashTy) }
	| TIMESTAMP LEFT_PAR RIGHT_PAR { $$ = NewNode(TimestampTy) }
	| GASPRICE LEFT_PAR RIGHT_PAR { $$ = NewNode(GasPriceTy) }
	| BLOCKNUM LEFT_PAR RIGHT_PAR { $$ = NewNode(BlockNumTy) }
	| COINBASE LEFT_PAR RIGHT_PAR { $$ = NewNode(CoinbaseTy) }
	| BALANCE LEFT_PAR RIGHT_PAR { $$ = NewNode(BalanceTy) }
	| GAS LEFT_PAR RIGHT_PAR { $$ = NewNode(GasTy) }
	| STORE LEFT_BRACKET expression RIGHT_BRACKET { $$ = NewNode(StoreTy, $3) }
	| STORE LEFT_BRACKET expression RIGHT_BRACKET ASSIGN expression
	  {
	      node := NewNode(SetStoreTy, $3)
	      $$ = NewNode(AssignmentTy, $6, node)
	  }
	;

if_statement
	: IF expression LEFT_BRACES statement_list RIGHT_BRACES optional_else_statement
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
	| /* Empty */ { $$ = nil }
	;

for_statement
	: FOR expression END_STMT expression END_STMT expression LEFT_BRACES statement_list RIGHT_BRACES
	  {
		  $$ = NewNode(ForThenTy, $2, $4, $6, $8)
	  }
	/* TODO */
	| FOR expression END_STMT expression LEFT_BRACES statement_list RIGHT_BRACES
	  {
		  $$ = NewNode(ForThenTy, $2, $4, $6)
	  }
	/* TODO */
	| FOR expression LEFT_BRACES statement_list RIGHT_BRACES
	  {
		  $$ = NewNode(ForThenTy, $2, $4)
	  }
	;

expression
	: op_expression { $$ = $1 }
	| assign_expression { $$ = $1 }
	| RETURN statement { $$ = NewNode(ReturnTy, $2) }
	| /* Empty */  { $$ = NewNode(EmptyTy) }
	;

op_expression
    /* ++, -- */
	: expression DOP { $$ = NewNode(OpTy, $1); $$.Constant = $2 } 
    /* Everything else */
	| expression OP sub_expression { $$ = NewNode(OpTy, $1, $3); $$.Constant = $2 }
	;

sub_expression
    : simple_expression { $$ = $1; }
    | op_expression { $$ = $1; }
    ;

assign_expression
	: ID ASSIGN expression
	  {
	      node := NewNode(SetLocalTy)
	      node.Constant = $1
	      $$ = NewNode(AssignmentTy, $3, node)
	  }
	| ID LEFT_BRACKET expression RIGHT_BRACKET ASSIGN assign_expression
	  {
	      $$ = NewNode(AssignArrayTy, $3, $6); $$.Constant = $1
	  }
	| new_var ASSIGN expression
	  {
	      node := NewNode(SetLocalTy)
	      node.Constant = $1.Constant
	      $$ = NewNode(AssignmentTy, $3, $1, node)
	  }
	| ID COLON ASSIGN expression
	  {
	  	node := NewNode(SetLocalTy)
		node.Constant = $1
	  	varNode := NewNode(NewVarTy); varNode.Constant = $1
		$$ = NewNode(AssignmentTy, $4, varNode, node)
	  }
	| new_var { $$ = $1 }
	| new_array { $$ = $1 }
	| simple_expression { $$ = $1 }
	;

new_var
	: VAR ID
	  {
	      $$ = NewNode(NewVarTy)
	      $$.Constant = $2
	      //$$.VarType = $1
	  }
	;

new_array
	: VAR LEFT_BRACKET NUMBER RIGHT_BRACKET ID
	  {
	      $$ = NewNode(NewArrayTy)
	      //$$.VarType = $1
	      $$.Size = $3
	      $$.Constant = $5
	      
	  }
	;

simple_expression
	: get_variable { $$ = $1 }
	;

get_variable
	: ptr { $$ = $1 }
	| NUMBER { $$ = NewNode(ConstantTy); $$.Constant = $1 }
	| ID LEFT_BRACKET expression RIGHT_BRACKET { $$ = NewNode(ArrayTy, $3); $$.Constant = $1 }
    	| BOOLEAN { $$ = NewNode(BoolTy); $$.Constant = $1 }
	| string { $$ = $1 }
	| buildins { $$ = $1 }
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

%%

