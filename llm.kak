declare-option -docstring "file containing anthropic api key" str llm_key_file "/home/enricozb/projects/utilities/kakoune/llm.kak/secrets/claude-api-key"
declare-option -hidden str llm_url "https://api.anthropic.com/v1/messages"
declare-option -hidden str llm_version "anthropic-version: 2023-06-01"
declare-option -hidden str llm_scratch

define-command llm %{
  evaluate-commands -draft %{
    execute-keys i{{{cursor}}}<esc>%

    llm-auto-complete

    execute-keys s\{\{\{cursor\}\}\}<ret>c %opt{llm_scratch} <esc>

    # clear the llm_scratch option
  }
}

define-command -hidden llm-auto-complete %{
  set-option buffer llm_scratch %sh{
    context=""

    eval set -- "$kak_quoted_buflist"
    while [ $# -gt 0 ]; do
      bufname=$1

      if [ "$bufname" = "$kak_bufname" ]; then
        context=$(printf '%s\n\n%s (current file):\n%s'  "${context}" "$bufname" "$(echo $kak_quoted_selection | sed 's/^/  /g')")
      elif [ -f "$1" ]; then
        context=$(printf '%s\n\n%s:\n%s'  "${context}" "$bufname" "$(cat "$1" | sed 's/^/  /g')")
      fi

      shift
    done

    curl ${kak_opt_llm_url} \
      -H "${kak_opt_llm_version}" \
      -H "content-type: application/json" \
      -H "x-api-key: $(cat ${kak_opt_llm_key_file})" \
      --data "$(jq -n --arg context "$context" '{
          "model": "claude-3-opus-20240229",
          "max_tokens": 1024,
          "system": "you are an auto-complete system for a text editor. you will be provided the content (as indented blocks) and paths of the files that are currently open in the editor, and the file that the user is currently working on. you will be provided with the cursor position, indicated by the text \"{{{cursor}}}\". pay attention to nearby comments and respond with what the user is trying to write. note that your entire response will replace \"{{{cursor}}}\" so respond ONLY with content that should be inserted into the current file, and nothing else. no yapping.",
          "messages": [
              {"role": "user", "content": $context}
          ]
      }')" | jq .content[0].text -r
  }
}

map global user l -docstring llm ': llm<ret>'
