:- dynamic variable/2.
:- dynamic base_dir/1.
:- prolog_load_context(directory, Dir), retractall(base_dir(_)), assertz(base_dir(Dir)).
:- use_module(library(tokenize)).

example_file('cmmExamples/example1.cmm').
example_file('cmmExamples/example2.cmm').
example_file('cmmExamples/example3.cmm').
example_file('cmmExamples/example4.cmm').
example_file('cmmExamples/example5.cmm').
example_file('cmmExamples/division.cmm').
example_file('cmmExamples/logic.cmm').
example_file('cmmExamples/reset.cmm').
example_file('cmmExamples/unassigned.cmm').
example_file('cmmExamples/whilenobraces.cmm').
example_file('cmmExamples/danglingelse.cmm').
example_file('cmmExamples/mixedbraces.cmm').
example_file('cmmExamples/printexpr.cmm').
example_file('cmmExamples/badcondition.cmm').

run_examples :-
    forall(example_file(Link), catch(run_file(Link), Error, report_error(Error))).

report_error(cmm_error(Message)) :- !, format("Error: ~w~n", [Message]), nl.
report_error(Error) :- print_message(error, Error), nl.

run_file(Link) :-
    retractall(variable(_,_)),
    base_dir(Dir),
    directory_file_path(Dir, Link, Path),
    (   tokenize_file(Path, RawTokens, [cased(true)]),
        remove_whitespace(RawTokens, Tokens),
        parse(Tokens, Ast, [])
    ->  (   run_statements(Ast)
        ->  true
        ;   format("Error: ~w was parsed but could not be run~n", [Link])
        )
    ;   format("Error: ~w could not be parsed~n", [Link])
    ),
    nl.


filter_list(A, In, Out) :- exclude(==(A), In, Out).


remove_whitespace(In, Out4) :- filter_list(space(' '),In,Out1) , filter_list(cntrl('\r'),Out1,Out2), filter_list(cntrl('\n'),Out2,Out3),   filter_list(cntrl('\t'),Out3,Out4).


 

parse(Tokens, Ast,Rest) :-
  phrase(program(Ast),Tokens,Rest),!.
 
program(Ss)   --> statements(Ss). %https://swish.swi-prolog.org/p/Compiler1.swinb

keyword(print).
keyword(if).
keyword(else).
keyword(while).

statement(assign(id(X), E)) --> identifier(X), {\+ keyword(X)}, [punct(=)] -> expression(E).

statement(If) -->
    [word(if)] -> [punct('(')], expression(T), [punct(')')], body(Then),
    (   [word(else)]
    ->  body(Else), {If = if(T, Then, Else)}
    ;   {If = if(T, Then)}
    ).

statement(while(T,S)) --> [word(while)] -> [punct('(')], expression(T), [punct(')')], body(S).
statement(print(Es)) --> [word(print)] -> expression_list(Es).
expression_list([E|Es]) --> expression(E), ( [punct(',')] -> expression_list(Es) ; {Es = []} ).


braced_block(S) --> [punct('{')], statements(S), [punct('}')].
body(S)          --> braced_block(S), !.
body((Stmt, [])) --> statement(Stmt).

statements((S, Ss))    -->   statement(S), statements(Ss).
statements([])  --> [].



value(num(N))     --> number_token(N), !.
value(id(X)) --> identifier(X), {\+ keyword(X)}.

number_token(X)              --> [number(X)].
identifier(X)              --> [word(X)].

run_statements([]). 
run_statements((LeftNode,RightTree)) :-  								 
	(LeftNode = assign(id(Id),E),	evaluate_expression(E,Results),    retractall(variable(Id,_)), assertz(variable(Id,num(Results))), run_statements(RightTree)),!;
	(LeftNode = print(List) , print_values(List),  run_statements(RightTree)),!; 
	 (LeftNode = if(T,S1,S2), condition_value(T,Results) , ((Results == 1, run_statements(S1));	(Results == 0, run_statements(S2))), run_statements(RightTree)),!;
	 (LeftNode = if(T,S), condition_value(T,Results), ((Results == 1, run_statements(S)); (Results == 0)), run_statements(RightTree)),!;
	 (LeftNode = while(T,S), condition_value(T,Results),  (	(Results == 1, run_statements(S),  run_statements((LeftNode,RightTree)))	; ( run_statements(RightTree) ) )	)	.
 
condition_value(T, Value) :-
    evaluate_expression(T, Value),
    (   (Value == 1 ; Value == 0)
    ->  true
    ;   format(atom(Message), "condition must be 1 or 0, but was ~w", [Value]),
        throw(cmm_error(Message))
    ).

evaluate_expression(Tree,Res) :- 
 	Tree = num(Res); (Tree = id(V), variable_value(V,Res));
(	(Tree = (Op, num(X), num(Y))) ; 	(Tree = (Op, id(V), num(Y)), variable_value(V,X)) ;	(Tree = (Op, num(X), id(V)), variable_value(V,Y)); 	(Tree = (Op, id(V1), id(V2)),  variable_value(V1,X),variable_value(V2,Y))	),
	
	( apply_comparison(Op,X,Y,Res);apply_logical(Op,X,Y,Res); apply_arithmetic(Op,X,Y,Res))	.


evaluate_expression((Op,LeftNode,RightNode),Res) :- 
											
evaluate_expression(LeftNode, ResLeft),  evaluate_expression(RightNode,ResRight),

( apply_comparison(Op,ResLeft,ResRight,Res); apply_logical(Op,ResLeft,ResRight,Res);apply_arithmetic(Op,ResLeft,ResRight,Res)).


apply_comparison(Op,X,Y,Res) :- (is_equality_op(Op); is_relational_op(Op)), Operate =.. [Op,X,Y] ,	((call(Operate),		Res is 1)	;	Res is 0).
								
apply_arithmetic(Op,X,Y,Res) :-  \+is_logical_op(Op), Operate =.. [Op,X,Y] , Res is Operate .


apply_logical((/\), X, Y, Res) :- ( X =\= 0, Y =\= 0 -> Res = 1 ; Res = 0 ).
apply_logical((\/), X, Y, Res) :- ( (X =\= 0 ; Y =\= 0) -> Res = 1 ; Res = 0 ).



print_values(Values) :-
    maplist(evaluate_expression, Values, Numbers),
    atomic_list_concat(Numbers, ' ', Line),
    write(Line), nl.

								
variable_value(Name, Value) :-
    (   variable(Name, num(Value))
    ->  true
    ;   format(atom(Message), "variable ~w is used before it is assigned", [Name]),
        throw(cmm_error(Message))
    ).


expression(T) -->  and_expression(E1), or_rest(E1,T). 	 

or_rest(E1,T) -->  [punct('|'),punct('|')],!, and_expression(E2),   {V  = (\/,E1,E2)}, or_rest(V,T).
or_rest(T,T) --> [].

and_expression(T) --> equality_expression(E1), and_rest(E1,T).
and_rest(E1,T) --> [punct(&),punct(&)], !, equality_expression(E2), {V  = (/\,E1,E2)}, and_rest(V,T).
and_rest(T,T) --> [].

equality_expression(T) -->   relational_expression(E1), equality_rest(E1,T).   
equality_rest(E1,T) --> equality_op(Op) ,!,  relational_expression(E2), {  V=(Op,E1,E2)}, equality_rest(V,T).
equality_rest(T,T) --> [].

relational_expression(T) --> comparison_operand(E1), relational_rest(E1,T). 
relational_rest(E1,T) -->  relational_op(Op) ,!, comparison_operand(E2) , { V=(Op,E1,E2) },relational_rest(V,T).
relational_rest(T,T) --> [].

comparison_operand(T) -->  additive_expression(T); [punct('(')], !, expression(T), [punct(')')]    	.


equality_op(==)         --> [punct(=),punct(=)]. 
equality_op(\=)        --> [punct(!),punct(=)]. 
relational_op(>=)        --> [punct(>),punct(=)]. 
relational_op(>)         --> [punct(>)]. 
relational_op('=<')        -->  [punct(<),punct(=)]. 
relational_op(<)         --> [punct(<)]. 

is_equality_op((Op)) :- Op == '==' ; Op == '\\='  .
is_relational_op((Op)):- Op == '>=' ; Op == '=<' ; Op == '>' ; Op == '<'.
is_logical_op((Op)):- (Op == /\) ; (Op == \/).

additive_expression(N) --> multiplicative_expression(N1), additive_rest(N1,N).%https://stackoverflow.com/questions/7543100/grammar-involving-braces

additive_rest(N1,N) --> [punct('+')], !, multiplicative_expression(N2), {N3 = (+,N1,N2)}, additive_rest(N3,N);  
						[punct('-')], !, multiplicative_expression(N2), {N3 = (-,N1,N2)}, additive_rest(N3,N).
additive_rest(N,N) --> [].

multiplicative_expression(N) --> factor(N1), multiplicative_rest(N1,N).
multiplicative_rest(N1,N) --> [punct('*')], !, factor(N2), {N3 = (*,N1,N2)}, multiplicative_rest(N3,N);
								[punct('/')], !, factor(N2), {N3 = (//,N1,N2)}, multiplicative_rest(N3,N);	
								[punct('%')], !, factor(N2), {N3 = (rem,N1,N2)}, multiplicative_rest(N3,N).
multiplicative_rest(N,N) --> [].

factor(N) --> [punct('(')], !, additive_expression(N), [punct(')')];  value(N). 





