function process(r::JSONRPC.Request{Val{Symbol("textDocument/completion")},TextDocumentPositionParams}, server)
    tdpp = r.params
    line = get_line(tdpp, server)
    
    word = IOBuffer()
    for c in reverse(line[1:chr2ind(line,tdpp.position.character)])
        if c=='\\'
            write(word, c)
            break
        end
        if !(Base.is_id_char(c) || c=='.' || c=='_' || c=='^')
            break
        end
        write(word, c)
    end
    
    str = reverse(takebuf_string(word))
    prefix = str[1:findlast(str,'.')]
    comp = Base.REPLCompletions.completions(str,endof(str))[1]
    n = length(comp)
    comp = comp[1:min(length(comp),25)]
    CIs = map(comp) do i
        s = get_sym(i)
        d = ""
        d = get_docs(s)
        d = isa(d,Vector{MarkedString}) ? (x->x.value).(d) : d
        d = join(d[2:end],'\n')
        d = replace(d,'`',"")

        label = i[1]=='\\' ? i[2:end] : i
        kind = 6
        if isa(s, String)
            kind = 1
        elseif isa(s, Function)
            kind = 3
        elseif isa(s, DataType)
            kind = 7
        elseif isa(s, Module)
            kind = 9
        elseif isa(s, Number)
            kind = 12
        elseif isa(s, Enum)
            kind = 13
        end

        l, c = tdpp.position.line, tdpp.position.character
        newtext = i[1]=='\\' ? Base.REPLCompletions.latex_symbols[i] : prefix*i

        if endof(newtext)>=endof(str)
            return CompletionItem(label, kind, d, TextEdit(Range(tdpp.position, tdpp.position), newtext[endof(str)+1:end]), [])
        else
            return CompletionItem(label, kind, d, TextEdit(Range(l, c-endof(str)+endof(newtext), l, c), ""),[TextEdit(Range(l, c-endof(str), l, c-endof(str)+endof(newtext)), newtext)])
        end
    end
    completion_list = CompletionList(25<n,CIs)

    response =  JSONRPC.Response(get(r.id), completion_list)
    send(response, server)
end

function JSONRPC.parse_params(::Type{Val{Symbol("textDocument/completion")}}, params)
    return TextDocumentPositionParams(params)
end