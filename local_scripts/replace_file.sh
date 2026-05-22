#/bin/sh
#cat local_replace.txt
#local_replace_files=($(cat local_replace.txt))
#read -ra local_replace_files <<< "$(cat local_replace.txt)"
#mapfile -t local_replace_files < local_replace.txt
readarray -t local_replace_files < local_replace.txt
readarray -t remote_replace_files < remote_replace.txt
#remote_replace_files=$(cat remote_replace.txt)
echo ${remote_replace_files[@]}

#echo ${local_replace_files[1]}
local_replace_filename=()
for file in "${local_replace_files[@]}"; do
	#local_replace_filename+=($(basename "$file"))
	#local_replace_filename+=("$(basename $file)");
	#basename $file;
	#dirname $file;
	for file_path in "${remote_replace_files[@]}"; do
		if [[ ${file_path} == *$(basename $file)  ]]; then
			scp minhthanh@172.21.162.42:${file_path} $file
			break
		fi
		
	done
done
#echo ${local_replace_filename[1]}
