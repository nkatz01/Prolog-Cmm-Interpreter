:- dynamic id/2.
:- use_module(library(tokenize)).
:- use_module(library(pprint)).
:- use_module(library(lists)).
file('cmmExamples/example1.cmm').
file('cmmExamples/example2.cmm').
file('cmmExamples/example3.cmm').
file('cmmExamples/example4.cmm').
file('cmmExamples/example5.cmm').
file('cmmExamples/division.cmm').
file('cmmExamples/logic.cmm').
file('cmmExamples/reset.cmm').
file('cmmExamples/unassigned.cmm').
file('cmmExamples/whilenobraces.cmm').
file('cmmExamples/danglingelse.cmm').
file('cmmExamples/mixedbraces.cmm').
file('cmmExamples/printexpr.cmm').


my_tokenize_file :-
    forall(file(Link), catch(run_file(Link), Error, report_error(Error))).

report_error(cmm_error(Message)) :- !, format("Error: ~w~n", [Message]), nl.
report_error(Error) :- print_message(error, Error), nl.

run_file(Link) :-
    retractall(id(_,_)),
    (   tokenize_file(Link, RawTokens, [cased(true)]),
        filterCtrlsAndDblSpaces(RawTokens, Tokens),
        parse(Tokens, Ast, [])
    ->  (   extractExp(Ast)
        ->  true
        ;   format("Error: ~w was parsed but could not be run~n", [Link])
        )
    ;   format("Error: ~w could not be parsed~n", [Link])
    ),
    nl.


filterList(A, In, Out) :- exclude(==(A), In, Out).


filterCtrlsAndDblSpaces(In, Out4) :- filterList(space(' '),In,Out1) , filterList(cntrl('\r'),Out1,Out2), filterList(cntrl('\n'),Out2,Out3),   filterList(cntrl('\t'),Out3,Out4).


 

parse(Tokens, Ast,Rest) :-
  phrase(pl_program(Ast),Tokens,Rest),!.
 
pl_program(Ss)   --> rest_statements(Ss). %https://swish.swi-prolog.org/p/Compiler1.swinb

keyword(print).
keyword(if).
keyword(else).
keyword(while).

statement(assign(id(X), E)) --> identifier(X), {\+ keyword(X)}, [punct(=)] -> cond_expre(E).

statement(If) -->
    [word(if)] -> [punct('(')], cond_expre(T), [punct(')')], body(Then),
    (   [word(else)]
    ->  body(Else), {If = if(T, Then, Else)}
    ;   {If = if(T, Then)}
    ).

statement(while(T,S)) --> [word(while)] -> [punct('(')], cond_expre(T), [punct(')')], body(S).
statement(print(Es)) --> [word(print)] -> expr_list(Es).
expr_list([E|Es]) --> cond_expre(E), ( [punct(',')] -> expr_list(Es) ; {Es = []} ).


compound(S) --> [punct('{')], rest_statements(S), [punct('}')].
body(S)          --> compound(S), !.
body((Stmt, [])) --> statement(Stmt).

rest_statements((S, Ss))    -->   statement(S), rest_statements(Ss).
rest_statements([])  --> [].



pl_constant(num(N))     --> pl_integer(N), !.
pl_constant(id(X)) --> identifier(X), {\+ keyword(X)}.

pl_integer(X)              --> [number(X)].
identifier(X)              --> [word(X)].

extractExp([]). 
extractExp((LeftNode,RightTree)) :-  								 
	(LeftNode = assign(id(Id),E),	evaluateExp(E,Results),    retractall(id(Id,_)), assertz(id(Id,num(Results))), extractExp(RightTree)),!;
	(LeftNode = print(List) , printStatements(List),  extractExp(RightTree)),!; 
	 (LeftNode = if(T,S1,S2), evaluateExp(T,Results) , ((Results == 1, extractExp(S1));	(Results == 0, extractExp(S2))), extractExp(RightTree)),!;
	 (LeftNode = if(T,S), evaluateExp(T,Results), ((Results == 1, extractExp(S)); (Results == 0)), extractExp(RightTree)),!;
	 (LeftNode = while(T,S), evaluateExp(T,Results),  (	(Results == 1, extractExp(S),  extractExp((LeftNode,RightTree)))	; ( extractExp(RightTree) ) )	)	.
 


evaluateExp(Tree,Res) :- 
 	Tree = num(Res); (Tree = id(V), traceID(V,Res));
(	(Tree = (Op, num(X), num(Y))) ; 	(Tree = (Op, id(V), num(Y)), traceID(V,X)) ;	(Tree = (Op, num(X), id(V)), traceID(V,Y)); 	(Tree = (Op, id(V1), id(V2)),  traceID(V1,X),traceID(V2,Y))	),
	
	( applyRelational(Op,X,Y,Res);applyLogical(Op,X,Y,Res); applyArith(Op,X,Y,Res))	.


evaluateExp((Op,LeftNode,RightNode),Res) :- 
											
evaluateExp(LeftNode, ResLeft),  evaluateExp(RightNode,ResRight),

( applyRelational(Op,ResLeft,ResRight,Res); applyLogical(Op,ResLeft,ResRight,Res);applyArith(Op,ResLeft,ResRight,Res)).


applyRelational(Op,X,Y,Res) :- (is_equality_op(Op); is_relat_op(Op)), Operate =.. [Op,X,Y] ,	((call(Operate),		Res is 1)	;	Res is 0).
								
applyArith(Op,X,Y,Res) :-  \+is_logical_op(Op), Operate =.. [Op,X,Y] , Res is Operate .


applyLogical((/\), X, Y, Res) :- ( X =\= 0, Y =\= 0 -> Res = 1 ; Res = 0 ).
applyLogical((\/), X, Y, Res) :- ( (X =\= 0 ; Y =\= 0) -> Res = 1 ; Res = 0 ).



printStatements(Values) :-
    maplist(evaluateExp, Values, Numbers),
    atomic_list_concat(Numbers, ' ', Line),
    write(Line), nl.

								
traceID(Name, Value) :-
    (   id(Name, num(Value))
    ->  true
    ;   format(atom(Message), "variable ~w is used before it is assigned", [Name]),
        throw(cmm_error(Message))
    ).


cond_expre(T) -->  and_expre(E1), or_rest(E1,T). 	 

or_rest(E1,T) -->  [punct('|'),punct('|')],!, and_expre(E2),   {V  = (\/,E1,E2)}, or_rest(V,T).
or_rest(T,T) --> [].

and_expre(T) --> equality_expre(E1), and_rest(E1,T).
and_rest(E1,T) --> [punct(&),punct(&)], !, equality_expre(E2), {V  = (/\,E1,E2)}, and_rest(V,T).
and_rest(T,T) --> [].

equality_expre(T) -->   relat_expre(E1), equality_rest(E1,T).   
equality_rest(E1,T) --> equality_op(Op) ,!,  relat_expre(E2), {  V=(Op,E1,E2)}, equality_rest(V,T).
equality_rest(T,T) --> [].

relat_expre(T) --> atomic_texpre(E1), relat_rest(E1,T). 
relat_rest(E1,T) -->  relat_op(Op) ,!, atomic_texpre(E2) , { V=(Op,E1,E2) },relat_rest(V,T).
relat_rest(T,T) --> [].

atomic_texpre(T) -->  arith_expre(T); [punct('(')], !, cond_expre(T), [punct(')')]    	.
arith_expre(V) --> expre(V).


opening_paren('(') --> [punct('(')].
closing_paren(')') --> [punct(')')].

equality_op(==)         --> [punct(=),punct(=)]. 
equality_op(\=)        --> [punct(!),punct(=)]. 
relat_op(>=)        --> [punct(>),punct(=)]. 
relat_op(>)         --> [punct(>)]. 
relat_op('=<')        -->  [punct(<),punct(=)]. 
relat_op(<)         --> [punct(<)]. 

is_equality_op((Op)) :- Op == '==' ; Op == '\\='  .
is_relat_op((Op)):- Op == '>=' ; Op == '=<' ; Op == '>' ; Op == '<'.
is_logical_op((Op)):- (Op == /\) ; (Op == \/).

expre(N) --> multiplicative(N1), additive_rest(N1,N).%https://stackoverflow.com/questions/7543100/grammar-involving-braces

additive_rest(N1,N) --> [punct('+')], !, multiplicative(N2), {N3 = (+,N1,N2)}, additive_rest(N3,N);  
						[punct('-')], !, multiplicative(N2), {N3 = (-,N1,N2)}, additive_rest(N3,N).
additive_rest(N,N) --> [].

multiplicative(N) --> atomic(N1), multiplicative_rest(N1,N).
multiplicative_rest(N1,N) --> [punct('*')], !, atomic(N2), {N3 = (*,N1,N2)}, multiplicative_rest(N3,N);
								[punct('/')], !, atomic(N2), {N3 = (//,N1,N2)}, multiplicative_rest(N3,N);	
								[punct('%')], !, atomic(N2), {N3 = (rem,N1,N2)}, multiplicative_rest(N3,N).
multiplicative_rest(N,N) --> [].

atomic(N) --> [punct('(')], !, expre(N), [punct(')')];  num(N). 
num(N) --> pl_constant(N).





