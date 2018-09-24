;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;			LOGO PARSER			    ;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;;THE FUNCTION OF THE PARSER IS TO CONVERT A LINE OF LOGO CODE TO
;;;LISP.  THE TOPLEVEL FUNCTION "PARSELINE" EXPECTS AS INPUT A LIST OF
;;;LOGO ATOMS AS, FOR EXAMPLE, ARE PRODUCED BY "LINE".  PARSELINE
;;;RETURNS THE EQUIVALENT LIST OF LISP S-EXPRESSIONS WHICH CAN THEN
;;;BE RUN BY "EVALS..
;;;
;;;THE GENERAL ATTACK IS FOR THE SPECIALISTS OF PARSE TO EXAMINE
;;;TOPARSE FOR THEIR SPECIALTY.  IF FOUND, THEY GENERATE AN 
;;;S-EXPRESSION WHICH IS PUSHED ONTO "PARSED" AND "TOPARSE" IS
;;;APPROPRIATELY PRUNED.  AN EXCEPTION TO THIS IS THAT PARSE-LOGOFN
;;;REPLACES THE PARSED EXPRESSION ONTO FIRST AND THEN TRIES 
;;;PARSE-INFIX.  THIS ALLOWS INFIX TO HAVE PRECEDENCE IN SITUATIONS
;;;OF THE FORM: "A"=B AND HEADING=360.
;;;
;;;
;;;F = COLLECT INPUTS TO END OF LINE WITHOUT PARSING
;;;L = COLLECT INPUTS TO END OF LINE PARSING
;;;NO. = FIXED NUMBER OF INPUTS		       
;;;(FNCALL) = SPECIAL PARSING FN TO BE EXECUTED.
;;;
;;;
;;FOR PROCEDURAL PARSING PROPERTIES, (GET ATOM 'PARSE) = ((PARSE-FN)), THE ENTRY
;;STATE IS THAT FIRST = FN, TOPARSE = REMAINDER OF LINE.  THE OUTPUT OF THE PARSE-FN
;;IS TO BE THE PARSED EXPR.  TOPARSE SHOULD BE POPPED IN THE PROCESS.

(DECLARE (OR (STATUS FEATURE DEFINE)
	     (COND ((STATUS FEATURE ITS)
		    ;;MULTICS?
		    (FASLOAD DEFINE FASL AI LLOGO))))) 

(SAVE-VERSION-NUMBER PARSER) 

(DECLARE (SETQ MACROS T) (GENPREFIX PARSER)) 

;;THE CATCH WILL TRAP THE RESULT OF A PARSING ERROR.  THE FUNCTION REREAD-ERROR WILL
;;TRY TO GET USER TO CORRECT THE LINE, AND WILL THROW BACK A CORRECTLY PARSED LINE. 
;;IF PARSELINE IS GIVEN A NON-NIL SECOND ARGUMENT, THEN A PARSING ERROR WILL SIMPLY
;;(ERR 'REREAD) OUT OF PARSELINE, INSTEAD OF ATTEMPTING TO RECOVER.

(DEFUN PARSELINE ARGS 
       (COND ((EQ (ARG 1.) EOF) EOF)
	     ((CATCH (DO ((PARSED NIL (CONS (PARSE NIL) PARSED))
			  (REREAD-ERROR? (AND (> ARGS 1.) (ARG 2.)))
			  (TOPARSE (APPEND (AND (NUMBERP (CAR (ARG 1.)))
						(OR (NOT :EDITMODE)
						    (EQ PROMPTER '>))
						'(INSERT-LINE))
					   (ARG 1.))))
			 ((NULL TOPARSE)
			  (COND (PARSED (NREVERSE PARSED)) (NULL-LINE))))
		     PARSELINE)))) 

[(OR ITS DEC10) (ARGS 'PARSELINE '(1. . 2.))] 

(SETQ FLAG NIL :EDITMODE T) 

[CLOGO (DEFINE PARSE-CLOGO-HOMONYM FEXPR (X) 
	(COND (:CAREFUL (AND (CDDR X)
			     (IOG NIL
				  (TYPE '"HOMONYM: REPLACING "
					FIRST
					'" BY "
					(CAR X))))
			(SETQ TOPARSE (CONS (CAR X) TOPARSE))
			(PARSE FLAG))
	      ((PARSE1 (CADR X)))))] 

;;THE PARSE FUNCTION IS SUB-STRUCTURED.  PARSE1 PARSES WITH A GIVEN PARSE PROPERTY. 
;;PROP SHOULD BE LAMBDA VARIABLE AS IT IS MODIFIED BY PARSE-PROP.

(DEFUN PARSE (FLAG) 
       (COND ((ATOM TOPARSE) (SETQ TOPARSE NIL))
	     ((LET ((FIRST (CAR TOPARSE)) (PROP))
		   (POP TOPARSE)
		   (PARSE1 (PARSE-PROP FIRST)))))) 

;;FIRST IS THE THING CURRENTLY BEING WORKED ON [I.E.  FUNCTION NAME] , TOPARSE IS
;;NOW THE REST OF THE LINE.

(DEFUN PARSE1 (PROP) 
       (SETQ FIRST (COND ((NULL PROP) (PARSE-?))
			 ((ATOM PROP) (PARSE-LOGOFN PROP))
			 ((AND (CDR PROP) (ATOM (CDR PROP)))
			  (CONS FIRST (PARSE-LEXPR-ARGS (CAR PROP) (CDR PROP))))
			 ((EVAL PROP))))
       (PARSE-INFIX)) 

;; TO ELIMINATE HOMONYMS [WORDS THAT MEAN ONE THING IN LISP, ANOTHER IN LOGO], THE
;;PARSER WILL TRANSFORM THEM INTO ALTERNATE WORDS, UNPARSER, PRINTER WILL CHANGE
;;THEM BACK.  PITFALL IN CURRENT METHOD OF HANDLING HOMONYMS: WHEN PASSING
;;FUNCTIONAL ARUGUMENTS IN CERTAIN CASES, THE PARSER DOES NOT GET A CHANCE TO DO ITS
;;THING, SO USER MAY FIND UNEXPECTED FUNCTION CALLED.  EXAMPLE: APPLY 'PRINT ..... 
;;CALLS LISP'S PRINT FN, NOT LOGO'S.

(DEFUN PARSE-SUBSTITUTE (REAL) (PARSE1 (PARSE-PROP (SETQ FIRST REAL)))) 

;;FINDS PARSE PROPERTY FOR X.  X MUST BE A PNAME TYPE ATOM.  IF PARSE-PROP GETS A
;;LIST, RETURNS NIL.  EXPLICIT PARSE PROPERTY IF INSIDE USER-PARENS USE SECOND
;;ELEMENT OF PARSE PROPERTY, IF THERE IS ONE.  ARRAY IS HANDLED AS AN EXPR OF NUMBER
;;OF DIMENSIONS ARGS.  TREAT X AS A VARIABLE IF IT'S BOUND OR FIRST LETTER IS COLON.

(DEFUN PARSE-PROP (X) 
       (COND
	((NOT (SYMBOLP X)) NIL)
	((SETQ PROP (ABBREVIATIONP X)) (PARSE-PROP (SETQ FIRST PROP)))
	((SETQ PROP (GET X 'PARSE))
	 (COND ((AND (EQ FLAG 'USER-PAREN) (CDR PROP)) (CADR PROP))
	       ((CAR PROP))))
	((HOW-TO-PARSE-INPUTS X))
	((BOUNDP X) NIL)
	((EQ (GETCHAR X 1.) ':) NIL)
	(INSERTLINE-NUMBER (THROW (NCONS (LIST 'INSERT-LINE
					       INSERTLINE-NUMBER
					       (CCONS 'PARSEMACRO
						      FIRST
						      (LIST FN INSERTLINE-NUMBER)
						      OLD-LINE)))
				  PARSELINE))
	;;X IS AN UNKNOWN FUNCTION.  IF EDITING, THROW. 
	((REREAD-ERROR
	  (LIST FIRST
		'" IS AN UNDEFINED FUNCTION "))))) 

(DEFUN HOW-TO-PARSE-INPUTS (FUNCTION) 
       ;;FIND FIRST FUNCTION PROPERTY ON PLIST OF X. 
       (LET ((GETL (FUNCTION-PROP FUNCTION)))
	    (COND ((MEMQ (CAR GETL) '(FEXPR FSUBR MACRO)) 'F)
		  ((EQ (CAR GETL) 'EXPR)
		   ;;PARSE PROPERTY OF AN EXPR IS THE NUMBER OF INPUTS.
		   (LET ((ARGLIST (CADADR GETL)))
			(COND ((AND ARGLIST (ATOM ARGLIST))
			       (PARSE-ARGS-PROP FUNCTION))
			      ((LENGTH ARGLIST)))))
		  ((MEMQ (CAR GETL) '(LSUBR SUBR)) (PARSE-ARGS-PROP FUNCTION))
		  ((EQ (CAR GETL) 'ARRAY)
		   (1- (LENGTH (ARRAYDIMS FUNCTION))))))) 

(DEFUN PARSE-ARGS-PROP (FUNCTION) 
       (LET ((ARGS-PROP (ARGS FUNCTION)))
	    (COND ((NULL ARGS-PROP) 'L)
		  ((NULL (CAR ARGS-PROP)) (CDR ARGS-PROP))
		  (ARGS-PROP)))) 

(DEFUN EOP NIL 
       (OR (NULL TOPARSE)
	   (AND (EQ (TYPEP (CAR TOPARSE)) 'LIST)
		(EQ (CAAR TOPARSE) 'LOGO-COMMENT)))) 

;;FIRST IS SET TO PARSED FN AND TOPARSE IS APPROPRIATELY POPPED.  PROP IS THE NUMBER
;;OF INPUTS.

(DEFUN PARSE-LOGOFN (PROP) 
       (CONS
	FIRST
	(COND ((EQ PROP 'F) (PARSE-FEXPR-ARGS))
	      ((EQ PROP 'L) (PARSE-LEXPR-ARGS 0. 999.))
	      ((NUMBERP PROP) (PARSE-EXPR-ARGS PROP))
	      ((REREAD-ERROR '"SYSTEM BUG - PARSE-LOGOFN"))))) 

(DEFUN PARSE-FEXPR-ARGS NIL 
       (COND ((EOP) NIL)
	     ((CONS (CAR TOPARSE) (PROG2 (POP TOPARSE) (PARSE-FEXPR-ARGS)))))) 

;;PICK UP INPUTS TO FUNCTIONS EXPECTING AN INDEFINITE NUMBER OF EVALUATED ARGUMENTS. 
;;PARSING OF ARGUMENTS MUST HALT AT INFIX OPERATOR, BECAUSE FIRST OPERAND IS MEANT
;;TO BE THE WHOLE FORM, AND INFIX OPERATOR DOES NOT BEGIN ANOTHER ARGUMENT TO THE
;;LEXPR.  EXAMPLE:
;;;	10 TEST YOUR.FAVORITE.LEXPR :ARG1 ... :ARGN = :RANDOM

(DEFUN PARSE-LEXPR-ARGS (AT-LEAST AT-MOST) 
       (COND ((OR (EOP) (GET (CAR TOPARSE) 'PARSE-INFIX))
	      (AND (PLUSP AT-LEAST)
		   (REREAD-ERROR (LIST '"TO FEW INPUTS TO "
				       (UNPARSE-FUNCTION-NAME FIRST)))))
	     ((ZEROP AT-MOST) NIL)
	     ((CONS (PARSE FIRST) (PARSE-LEXPR-ARGS (1- AT-LEAST) (1- AT-MOST)))))) 

(DEFUN PARSE-EXPR-ARGS (HOWMANY) 
       (COND ((= HOWMANY 0.) NIL)
	     ((EOP)
	      (REREAD-ERROR (LIST '"TOO FEW INPUTS TO "
				  (UNPARSE-FUNCTION-NAME FIRST))))
	     ((CONS (PARSE FIRST) (PARSE-EXPR-ARGS (1- HOWMANY)))))) 

(DEFUN PARSE-FORM-LIST NIL 
       (COND ((EOP) NIL) ((CONS (PARSE FIRST) (PARSE-FORM-LIST))))) 

;;*PAGE

;;PRECEDENCE FUNCTION ALLOWS USER TO CHANGE PRECEDENCE AS HE WISHES.  (PRECEDENCE
;;<OP>) RETURNS PRECEDENCE NUMBER OF <OP>.  (PRECEDENCE <OP> <LEVEL>) SETS
;;PRECEDENCE OF <OP> TO <LEVEL>, EITHER A NUMBER OR OPERATOR, WHICH MAKES IT SAME
;;PRECEDENCE AS 	THAT OPERATOR.  <LEVEL>= NIL MEANS LOWEST PRECEDENCE. 
;;(PRECEDENCE NIL <NUMBER>) SETS THE DEFAULT PRECEDENCE FOR IDENTIFIERS TO <NUMBER>.

(DEFINE PRECEDENCE ARGS 
	(COND ((= ARGS 1.)
	       (COND ((NULL (ARG 1.)) 0.)
		     ((GET (ARG 1.) 'INFIX-PRECEDENCE))
		     (DEFAULT-PRECEDENCE)))
	      ((ARG 1.)
	       (PUTPROP (ARG 1.)
			(COND ((NUMBERP (ARG 2.)) (ARG 2.)) ((PRECEDENCE (ARG 2.))))
			'INFIX-PRECEDENCE))
	      ((SETQ DEFAULT-PRECEDENCE (NUMBER? 'PRECEDENCE (ARG 2.)))))) 

[(OR ITS DEC10) (ARGS 'PRECEDENCE '(1. . 2.))] 

;; (ASSOCIATE <LEVEL> <WHICH-WAY>) CAUSES ALL OPERATORS OF PRECEDENCE <LEVEL> TO
;;ASSOCIATE TO RIGHT, OR LEFT, AS SPECIFIED.  DEFAULT IS LEFT ASSOCIATIVE. 
;;RIGHT-ASSOCIATIVE IS LIST OF LEVELS WHICH ARE NOT.

(DEFINE ASSOCIATE (LEVEL WHICH-WAY) 
	(SETQ LEVEL (NUMBER? 'ASSOCIATE LEVEL))
	(COND ((EQ WHICH-WAY 'RIGHT) (PUSH LEVEL RIGHT-ASSOCIATIVE))
	      ((EQ WHICH-WAY 'LEFT)
	       (SETQ RIGHT-ASSOCIATIVE (DELETE LEVEL RIGHT-ASSOCIATIVE)))
	      ((ERRBREAK 'ASSOCIATE
			 '"INPUT MUST BE RIGHT OR LEFT")))
	WHICH-WAY) 

;; (INFIX <OP> <PRECEDENCE> ) CREATES <OP> TO BE A NEW INFIX OPERATOR, OPTIONALLY
;;SPECIFYING A PRECEDENCE LEVEL.

(DEFINE INFIX ARGS 
	(PUTPROP (ARG 1.) (ARG 1.) 'PARSE-INFIX)
	(PUTPROP (ARG 1.) (ARG 1.) 'UNPARSE-INFIX)
	(PUSH (ARG 1.) :INFIX)
	(AND (= ARGS 2.)
	     (PUTPROP (ARG 1.)
		      (COND ((NUMBERP (ARG 2.)) (ARG 2.)) ((PRECEDENCE (ARG 2.))))
		      'INFIX-PRECEDENCE))
	(ARG 1.)) 

[(OR ITS DEC10) (ARGS 'INFIX '(1. . 2.))] 

;;NOPRECEDENCE MAKES EVERY INFIX OPERATOR HAVE THE SAME PRECEDENCE, AS CLOGO DOES. 
;;LOGICAL FUNCTIONS HAVE PRECEDENCE LOWER THAN DEFAULT FUNCTIONS, INFIX HIGHER.

(DEFINE NOPRECEDENCE NIL 
	(SETQ DEFAULT-PRECEDENCE 300.)
	(MAPC 
	 '(LAMBDA (OP) (PUTPROP OP (1+ DEFAULT-PRECEDENCE) 'INFIX-PRECEDENCE))
	 :INFIX)
	(MAPC '(LAMBDA (OP) (REMPROP OP 'INFIX-PRECEDENCE))
	      '(IF NOT BOTH EITHER TEST AND OR))
	NO-VALUE) 

;;THIS FUNCTION PARSES INFIX EXPRESSIONS.  ON ENTRY, FIRST IS THE FORM THAT WAS JUST
;;PARSED, TOPARSE REMAINDER OF LINE.  IF THE EXPRESSION IS INFIX, NEXT WILL BE AN
;;INFIX OPERATOR.  FLAG, THE INPUT TO PARSE, MAY BE NIL, USER-PAREN, OR A FUNCTION
;;NAME.  IF PRECEDENCE OF FLAG, IS GREATER THAN PRECEDENCE OF NEXT, INFIX EXPRESSION
;;IS OVER, RETURN FIRST.  ELSE CONTINUE PARSING SECOND INPUT TO INFIX OPERATOR. 
;;ASSOCIATIVITY IS DECIDED BY PARSING DECISION MADE WHEN PRECEDENCES ARE EQUAL.  A
;;SPECIAL KLUDGE IS NECESSARY FOR HANDLING MINUS SIGN- PASS2 CONVERTS ALL MINUS
;;SIGNS FOLLOWED BY NUMBERS TO NEGATIVE NUMBERS; RECONVERSION MAY BE NECESSARY. 

(DEFUN PARSE-INFIX NIL 
       (DO ((NEXT (CAR TOPARSE) (CAR TOPARSE))
	    (INFIX-OP (GET (CAR TOPARSE) 'PARSE-INFIX)
		      (GET (CAR TOPARSE) 'PARSE-INFIX))
	    (NEXT-LEVEL (PRECEDENCE (CAR TOPARSE)) (PRECEDENCE (CAR TOPARSE)))
	    (FLAG-LEVEL (PRECEDENCE FLAG))
	    (DASH))
	   (NIL)
	   (COND (INFIX-OP)
		 ((AND (NUMBERP NEXT)
		       (MINUSP NEXT)
		       (SETQ DASH (GET '- 'PARSE-INFIX)))
		  (SETQ INFIX-OP DASH 
			NEXT-LEVEL (PRECEDENCE '-) 
			NEXT '-)
		  (RPLACA TOPARSE (MINUS (CAR TOPARSE)))
		  (PUSH '- TOPARSE))
		 ((RETURN FIRST)))
	   (COND ((AND (NUMBERP FIRST)
		       (MINUSP FIRST)
		       (GREATERP NEXT-LEVEL (PRECEDENCE 'PREFIX-MINUS)))
		  (PUSH (MINUS FIRST) TOPARSE)
		  (SETQ FIRST (LIST 'PREFIX-MINUS
				    (PARSE 'PREFIX-MINUS))))
		 ((GREATERP NEXT-LEVEL FLAG-LEVEL) (PARSE-INFIX-LEVEL NEXT INFIX-OP))
		 ((EQUAL NEXT-LEVEL FLAG-LEVEL)
		  (COND ((MEMBER NEXT-LEVEL RIGHT-ASSOCIATIVE)
			 (PARSE-INFIX-LEVEL NEXT INFIX-OP))
			((RETURN FIRST))))
		 ((RETURN FIRST))))) 

(DEFUN PARSE-INFIX-LEVEL (NEXT INFIX-OP) 
       (POP TOPARSE)
       (AND (EOP)
	    (REREAD-ERROR (LIST '"TOO FEW INPUTS TO"
				(UNPARSE-FUNCTION-NAME NEXT))))
       (SETQ FIRST (LIST INFIX-OP FIRST (PARSE NEXT)))) 

;;INITIAL DEFAULT PRECEDENCES.  NIL & USER-PAREN HAVE PRECEDENCE 0, (PARSE NIL)
;;,(PARSE 'USER-PAREN) PICKS UP A FORM- MAXIMAL INFIX EXPRESSION.  BOOLEAN FUNCTIONS
;;ARE GIVEN LOWER PRECEDENCE THAN COMPARISON OPERATORS.  DEFAULT PRECEDENCE IS 300. 
;;INITIALLY, ONLY EXPONENTIATION AND ASSIGNMENT ARE RIGHT ASSOCIATIVE.  THESE ARE
;;THE PRECEDENCE LEVELS USED BY 11LOGO.

(MAPC '(LAMBDA (INFIX PREFIX) (PUTPROP INFIX PREFIX 'PARSE-INFIX)
			      (PUTPROP PREFIX INFIX 'UNPARSE-INFIX))
      '(+ - * // \ < > = ^ _)
      '(INFIX-PLUS INFIX-DIFFERENCE INFIX-TIMES INFIX-QUOTIENT INFIX-REMAINDER
	INFIX-LESSP INFIX-GREATERP INFIX-EQUAL INFIX-EXPT INFIX-MAKE)) 

;;THEN AND ELSE ARE CONSIDERED AS "INFIX" SO THAT THEY WILL TERMINATE PARSING OF
;;INPUTS TO LEXPR-TYPE FUNCTIONS, WHERE THE EXTENT OF A FORM ISN'T REALLY CLEARLY
;;DELINEATED.  SINCE THEY HAVE LOWER PRECEDENCE THAN ANYTHING ELSE, THEY WILL NEVER
;;REALLY BE PARSED AS INFIX.

(DEFPROP THEN THEN PARSE-INFIX) 

(DEFPROP ELSE ELSE PARSE-INFIX) 

(DEFPROP THEN 0. INFIX-PRECEDENCE) 

(DEFPROP ELSE 0. INFIX-PRECEDENCE) 

(SETQ :INFIX '(_ < > = + - * // \ PREFIX-MINUS PREFIX-PLUS ^)) 

(MAPC '(LAMBDA (OP LEVEL) (PUTPROP OP LEVEL 'INFIX-PRECEDENCE))
      :INFIX
      '(50. 200. 200. 200. 400. 400. 500. 500. 500. 600. 600. 700.)) 

(MAPC '(LAMBDA (OP LEVEL) (PUTPROP OP LEVEL 'INFIX-PRECEDENCE))
      '(NIL USER-PAREN IF BOTH NOT EITHER TEST AND OR)
      '(0. 0. 100. 100. 100. 100. 100. 100. 100.)) 

(SETQ DEFAULT-PRECEDENCE 300.) 

(SETQ RIGHT-ASSOCIATIVE '(50. 700.)) 

;;INFIX-MAKE SHOULD PROBABLY HAVE DIFFERENT PRECEDENCES FROM RIGHT AND LEFT SIDES:
;;;	:A + :B _ 17  ==> (PLUS :A (MAKE :B 17))
;;;	:A _ :B + 17  ==> (MAKE :A (PLUS :B 17))
;;;
;;USER PARENTHESIS MARKER.

(DEFINE USER-PAREN (X) X) 

(DEFUN PARSE-? NIL 
       (COND
	((AND (EQ (TYPEP FIRST) 'LIST)
	      (NOT (MEMQ (CAR FIRST)
			 '(LOGO-COMMENT QUOTE DOUBLE-QUOTE SQUARE-BRACKETS))))
	 (LIST
	  'USER-PAREN
	  (LET
	   ((TOPARSE FIRST))
	   (PROG2
	    NIL
	    (PARSE 'USER-PAREN)
	    ;;MORE THAN ONE FORM INSIDE PARENTHESES. 
	    (AND
	     TOPARSE
	     (REREAD-ERROR
	      (LIST '"TOO MUCH INSIDE PARENTHESES."
		    TOPARSE
		    '"IS EXTRA")))))))
	((AND (NUMBERP FIRST) (NULL FLAG))
	 (REREAD-ERROR (LIST '"A NUMBER ISN'T A FUNCTION"
			     FIRST)))
	(FIRST))) 

;;CONVERTS IF TO LISP "COND"

(DEFUN PARSEIF NIL 
       (PROG (TRUES FALSES) 
	     (COND ((EQ (CAR TOPARSE) 'TRUE)
		    (SETQ TOPARSE (CONS 'IFTRUE (CDR TOPARSE)))
		    (RETURN (PARSE NIL)))
		   ((EQ (CAR TOPARSE) 'FALSE)
		    (SETQ TOPARSE (CONS 'IFFALSE (CDR TOPARSE)))
		    (RETURN (PARSE NIL))))
	     (SETQ TRUES (LIST (PARSE 'IF)))
	     (AND (EQ (CAR TOPARSE) 'THEN) (POP TOPARSE))
	LOOP1(COND ((EOP) (GO DONE))
		   ((EQ (CAR TOPARSE) 'ELSE) (POP TOPARSE) (GO LOOP2)))
	     (PUSH (PARSE NIL) TRUES)
	     (GO LOOP1)
	LOOP2(COND ((EOP) (GO DONE))
		   ;;ANOTHER ELSE WILL TERMINATE PARSING OF ELSE CLAUSES.
		   ((EQ (CAR TOPARSE) 'ELSE) (GO DONE)))
	     (PUSH (PARSE NIL) FALSES)
	     (GO LOOP2)
	DONE (SETQ TRUES (NREVERSE TRUES))
	     (SETQ FALSES (NREVERSE FALSES))
	     (RETURN (COND (FALSES (LIST 'COND TRUES (CONS T FALSES)))
			   ((LIST 'COND TRUES)))))) 

(DEFUN PARSE-SETQ NIL 
       (PROG (PARSED) 
	     (AND (EOP)
		  (REREAD-ERROR '" - NO INPUTS TO SETQ"))
	     (SETQ PARSED (LIST FIRST))
	A    (AND (EOP) (RETURN (NREVERSE PARSED)))
	     (OR
	      (SYMBOLP (CAR TOPARSE))
	      (REREAD-ERROR
	       (LIST '"THE INPUT "
		     (CAR TOPARSE)
		     '" TO "
		     FIRST
		     '" WAS NOT A VALID VARIABLE NAME")))
	     (PUSH (CAR TOPARSE) PARSED)
	     ;;VARIABLE NAME
	     (POP TOPARSE)
	     (AND
	      (EOP)
	      (REREAD-ERROR
	       (LIST '" - WRONG NUMBER INPUTS TO"
		     FIRST)))
	     ;;VALUE
	     (PUSH (PARSE FIRST) PARSED)
	     (GO A))) 

(DEFUN PARSE-STORE NIL 
       ;;SPECIAL PARSING FUNCTION FOR STORE.  LISP STORE MANAGES TO GET CONFUSED BY
       ;;USER-PAREN FUNCTION TACKED ONTO ARRAY CALL ARGUMENT, EVEN THO USER-PAREN
       ;;DOES NOTHING [DON'T ASK ME WHY].  ALSO, MAKE A HALF-HEARTED ATTEMPT AT
       ;;MAKING 11LOGO-STYLE STORE WORK.
       (CONS FIRST
	     (LET ((ARRAY-CALL (PARSE 'STORE)))
		  (COND ((OR (ATOM ARRAY-CALL) (EQ (CAR ARRAY-CALL) 'QUOTE))
			 ;;11LOGO STYLE STORE.  STORE <ARRAY> <DIM1>..<DIM N>
			 ;;<VALUE>.
			 (LIST (COND ((EQ FLAG 'USER-PAREN)
				      ;;IF PARENTHESIZED, ALL BUT LAST ARGS ARE
				      ;;DIMS.
				      (DO ((DIMENSIONS NIL
						       (CONS (PARSE 'STORE)
							     DIMENSIONS)))
					  ((NULL (CDR TOPARSE))
					   (CONS ARRAY-CALL (NREVERSE DIMENSIONS)))))
				     ;;DEFAULT UNPARENTHESIZED PARSING IS 1 DIM. 
				     ;;ARRAY
				     ((LIST ARRAY-CALL (PARSE 'STORE))))
			       (PARSE 'STORE)))
			((EQ (CAR ARRAY-CALL) 'USER-PAREN)
			 ;;UNFORTUNATELY LOSES PAREN INFO HERE.  PERHAPS HAVE
			 ;;ADDITIONAL FUNCTION STORE-PAREN WHICH UNPARSES WITH
			 ;;PARENS?
			 (LIST (CADR ARRAY-CALL) (PARSE 'STORE)))
			((LIST ARRAY-CALL (PARSE 'STORE))))))) 

(DEFUN PARSE-BREAK NIL 
       (CONS FIRST
	     (AND TOPARSE
		  (CONS (CAR TOPARSE)
			(AND (POP TOPARSE)
			     (CONS (PARSE NIL) (AND TOPARSE (LIST (PARSE NIL))))))))) 

(DEFUN PARSE-DO NIL 
       (CONS FIRST
	     (LET ((VAR-SPECS (CAR TOPARSE)) (STOP-RULE (CADR TOPARSE)))
		  (COND ((AND VAR-SPECS (ATOM VAR-SPECS))
			 (PARSE-LEXPR-ARGS 4. 99999.))
			;;Old or new style DO?
			((CCONS (PARSE-VARIABLE-SPEC VAR-SPECS)
				;;Variable specs, stop rule...
				(LET ((TOPARSE STOP-RULE))
				     (PARSE-LEXPR-ARGS 0. 99999.))
				;;..and the body.
				(AND (SETQ TOPARSE (CDDR TOPARSE))
				     (PARSE-LEXPR-ARGS 0. 99999.)))))))) 

(DEFUN PARSE-VARIABLE-SPEC (VAR-SPECS) 
       (MAPCAR 
	'(LAMBDA (TOPARSE) 
	  (PROG1
	   (PARSE-LEXPR-ARGS 1. 3.)
	   (AND
	    TOPARSE
	    (REREAD-ERROR '"TOO MUCH IN DO VARIABLE LIST"))))
	VAR-SPECS)) 

;;IGNORE CARRIAGE RETURN WHICH MIGHT FIND ITS WAY INTO A FORM DUE TO MULTI-LINE
;;PARENTHESIZED FORM FEATURE.

(PUTPROP EOL '((PARSE NIL)) 'PARSE) 

(DEFUN PARSE-GO NIL 
       (AND (EQ (CAR TOPARSE) 'TO) (POP TOPARSE))
       (AND (EQ (CAR TOPARSE) 'LINE) (POP TOPARSE))
       (AND (EOP)
	    (REREAD-ERROR (LIST '"TOO FEW INPUTS TO GO")))
       (LIST FIRST (PARSE 'GO))) 

;; INSERTLINE-NUMBER IS A GLOBAL VARIABLE CHECKED BY PARSE-PROP.  IT IS SET TO LINE
;;NUMBER TO BE INSERTED.  IF AN UNDEFINED FUNCTION IS ENCOUNTERED, THROW A
;;PARSEMACRO BACK TO PARSELINE.

(SETQ INSERTLINE-NUMBER NIL) 

;;FOR LINES INSERTED BY USER CALLS TO INSERTLINE, THE FIRST THING IN THE LINE MUST
;;BE A NUMBER.  COMMENTS NOT INCLUDED BY INSERTLINE.

(DEFUN PARSE-INSERTLINE NIL 
       (LET
	((LINE-NUMBER (CAR TOPARSE)))
	(SETQ TOPARSE (CDR TOPARSE) FIRST NIL)
	(OR
	 (NUMBERP LINE-NUMBER)
	 (REREAD-ERROR
	  '"INSERTED LINE MUST BEGIN WITH NUMBER"))
	(AND
	 (BIGP LINE-NUMBER)
	 (REREAD-ERROR
	  (LIST LINE-NUMBER
		'"IS TOO BIG TO BE A LINE NUMBER")))
	(AND (EOP)
	     (REREAD-ERROR '"INSERTING EMPTY LINE? "))
	(CCONS 'INSERTLINE LINE-NUMBER (PARSE-FORM-LIST)))) 

(DEFUN PARSE-INSERT-LINE NIL 
       (LET
	((INSERTLINE-NUMBER (CAR TOPARSE)))
	(SETQ TOPARSE (CDR TOPARSE) FIRST NIL)
	(OR TOPARSE
	    (REREAD-ERROR '"NO CODE FOLLOWING LINE NUMBER?"))
	(AND
	 (BIGP INSERTLINE-NUMBER)
	 (REREAD-ERROR
	  (LIST INSERTLINE-NUMBER
		'"IS TO BIG TO BE A LINE NUMBER")))
	(NCONC (CCONS 'INSERT-LINE INSERTLINE-NUMBER (PARSE-FORM-LIST))
	       (AND TOPARSE
		    ;;(CAAR NIL) IS A NO-NO.
		    (EQ (CAAR TOPARSE) 'LOGO-COMMENT)
		    TOPARSE)))) 

;;;LINE CONTAINED A FUNCTION NAME WHICH DID NOT HAVE A DEFINITION AT COMPILE TIME. 

(DEFINE PARSEMACRO MACRO (X) 
 (LET
  ((OLD-LINE (CDDDR X))
   (PARSEMACRO-FN (CAR (CADDR X)))
   (NUMBER (CADR (CADDR X)))
   (OLD-FN FN)
   (PROMPTER '>))
  (DEFAULT-FUNCTION 'PARSEMACRO PARSEMACRO-FN)
  (LIST
   'PARSEMACRO-EVAL
   (LIST 'QUOTE
	 (COND 
	       ;;DOES FUNCTION HAVE A DEFINITION AT EXECUTION TIME? YES, REPARSE IT.
	       ((FUNCTION-PROP (CADR X))
		(EVALS (PARSELINE (PASS2 OLD-LINE)))
		((LAMBDA (THIS-LINE NEXT-TAG LAST-LINE) 
			 (GETLINE PROG NUMBER)
			 (DEFAULT-FUNCTION 'PARSEMACRO OLD-FN)
			 THIS-LINE)
		 NIL
		 NIL
		 NIL))
	       ;;NO, CAUSE ERROR. 
	       ((IOG NIL
		     (TYPE '";ERROR IN LINE "
			   NUMBER
			   '" OF "
			   PARSEMACRO-FN
			   '" - "
			   (CADR X)
			   '" IS AN UNDEFINED FUNCTION"
			   EOL)
		     ((LAMBDA (NEW-LINE) 
			      (DEFAULT-FUNCTION 'PARSEMACRO OLD-FN)
			      (TYPE '";CONTINUING EVALUATION"
				    EOL)
			      NEW-LINE)
		      (EDIT-LINE NUMBER))))))))) 
