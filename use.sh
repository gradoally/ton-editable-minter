#!/root//bash/bash-3.2.57/bash

# Скачать бинарники (пребилды) func, fift и lite-client можно тут: https://github.com/ton-blockchain/ton/actions?query=branch%3Amaster+is%3Acompleted

# Пути к бинарникам func и fift (надо указать свои). 
path_to_func_binaries=/root/ton-build/crypto/func # func
path_to_fift_binaries=/root/ton-build/crypto/fift # fift
path_to_lite_client_binaries=/root/ton-build/lite-client/lite-client # lite-client


# Пути к библиотекам func и fift
fift_libs=lib/fift # там находятся Asm.fif, TonUtil.fif, Fift.fif и т.д.
func_stdlib=lib/func/stdlib.fc # стандартная библиотека FunC
fift_cli=lib/cli.fif # Библиотека CLI

# Конфиги
mainnet=config/global.config.json # mainnet
testnet=config/testnet-global.config.json # testnet

# Пути к вспомогательным файлам
func_params=utils/params.fc # проверка воркчейна, включаем во все смарты
func_op_codes=utils/op-codes.fc # выносим op-коды в этот файл

# Пути к нашим контрактам
func_collection_contract=src/contracts/nft-collection-editable.fc # контракт коллекции
func_nft_contract=src/contracts/nft-item-editable.fc
func_minter_contract=src/contracts/nft-collection-minter.fc # контракт минтера коллекции

# Пути к папкам
fift_contracts=src/build # сюда скомпилируются fift-файлы

get_addr_from_file () { # pass directory to addr file and name of output var

    directory_to_addr_file=$1
    output_var_name=$2
    
    string_output_var_name="$output_var_name"
    eval $string_output_var_name=$($path_to_fift_binaries -I $fift_libs -s src/get-addr-from-file.fif $directory_to_addr_file)
    echo "Got addr from file: ${!string_output_var_name}"
    echo 'Addr saved to variable $'"${string_output_var_name}"

}

get_seqno_by_addr () { 

    net=$1
    addr=$2
    output_var_name=$3

    string_output_var_name="$output_var_name"

    for i in {1..30}
    do

        echo "Attempt to get seqno №$i"
        if [ $net = "mainnet" ]; then
            eval $string_output_var_name=$($path_to_lite_client_binaries -v 3 --timeout 3 -C $mainnet -v 2 -c "runmethod $addr 85143" | awk -v FS="(result: | remote)" '{print $2}' | tr -dc '0-9')
        elif [ $net = "testnet" ]; then
            eval $string_output_var_name=$($path_to_lite_client_binaries -v 3 --timeout 3 -C $testnet -v 2 -c "runmethod $addr 85143" | awk -v FS="(result: | remote)" '{print $2}' | tr -dc '0-9')
        else
            echo "Second argument is wrong. Should use testnet or mainnet"
        fi

        if [ ${!string_output_var_name} ];
        then
            echo "Success in attempt #$i"
            echo 'Seqno saved to variable $'"${string_output_var_name}"
            break
        fi

    done

}

create_fift_from_func_with_args () {

    input_func_file=$1
    output_fift_file=$2
    arguments=${@:3:$#}

    $path_to_func_binaries -SPA -o $output_fift_file $arguments $input_func_file

}

compile_collection () {

    base_uri=$1
    collection_uri=$2
    royalty_addr=$3
    owner_addr=$4
    royalty_numerator=$5

    create_fift_from_func_with_args $func_nft_contract src/build/nft/nft-item-editable.fif $func_stdlib $func_params $func_op_codes
    create_fift_from_func_with_args $func_collection_contract src/build/collection/nft-collection-editable.fif $func_stdlib $func_params $func_op_codes
    $path_to_fift_binaries -I $fift_libs -I $fift_contracts -s src/compile-collection.fif $base_uri $collection_uri $deploy_wallet_addr $deploy_wallet_addr $royalty_numerator # Запускаем скрипт, который создает boc-файл контракта минтера коллекций

}

send_ton_to_addr () { # three arguments: dest_addr, seqno, amount, net

    $path_to_fift_binaries -I $fift_libs -s src/external-to-wallet.fif plane_garage_wallet $1 $2 $3 -n src/build/messages/send-ton-to-minter
    
    for i in {1..30}
    do

        echo "Attempt to send ton №$i"

        if [ $4 = "mainnet" ]; then
            $path_to_lite_client_binaries -v 3 --timeout 3 -C $mainnet -v 2 -c 'sendfile src/build/messages/send-ton-to-minter.boc'
        elif [ $4 = "testnet" ]; then
            $path_to_lite_client_binaries -v 3 --timeout 3 -C $testnet -v 2 -c 'sendfile src/build/messages/send-ton-to-minter.boc'
        else
            echo "Net argument is wrong. Should use testnet or mainnet"
        fi

        if [ $? == "0" ];
        then
            echo "Success in attempt №$i"
            break
        fi

    done

}

send_boc () { # [net] [msg_directory] [action_name]

    net=$1
    msg_directory=$2
    action_name=$3

    for i in {1..30}
    do

        echo "Attempt to $action_name №$i"

        if [ $net = "mainnet" ]; then
            $path_to_lite_client_binaries -v 3 --timeout 3 -C $mainnet -v 2 -c "sendfile $msg_directory"
        elif [ $net = "testnet" ]; then
            $path_to_lite_client_binaries -v 3 --timeout 3 -C $testnet -v 2 -c "sendfile $msg_directory"
        else
            echo "Net argument is wrong. Should use testnet or mainnet"
        fi

        if [ $? -eq 0 ];
        then
            echo "Success to $action_name in attempt #$i"
            break
        fi

    done

}

# Compile deploy wallet, no args
if [ $1 = "compile-wallet" ]; then

    action_name=$1

    $path_to_fift_binaries -I $fift_libs -s src/new-wallet.fif 0 deploy-wallet

# sh use.sh deploy-wallet [net]
elif [ $1 = "deploy-wallet" ]; then
    
    action_name=$1
    net=$2

    send_boc $net src/build/wallet/deploy-wallet-query.boc $action_name

# sh use.sh deploy-collection [net] [base_uri] [collection_uri] [royalty percent * 10]
elif [ $1 = "deploy-collection" ]; then

    action_name=$1
    net=$2
    base_uri=$3
    collection_uri=$4
    royalty_numerator=$5

    get_addr_from_file src/build/wallet/deploy-wallet.addr deploy_wallet_addr # get deploy-wallet addr and saves it to $deploy_wallet_addr
    compile_collection $base_uri $collection_uri $deploy_wallet_addr $deploy_wallet_addr $royalty_numerator
    get_seqno_by_addr $net $deploy_wallet_addr deploy_wallet_seqno
    get_addr_from_file src/build/collection/nft-collection-editable.addr collection_addr
    send_ton_to_addr $collection_addr $deploy_wallet_seqno 0.05 $net
    sleep 10
    send_boc $net src/build/collection/nft-collection-query.boc $action_name

# sh use.sh add-collection-addr-to-file [user_file_directory]
elif [ $1 = "add-collection-addr-to-file" ]; then

    action_name=$1

    get_addr_from_file src/build/collection/nft-collection-editable.addr collection_addr
    default_file_directory=src/build/last_collection.txt
    echo $collection_addr > $default_file_directory
    echo "Collection address saved to default file $default_file_directory"

    if [ $2 ]
    then

        user_file_directory=$2
        echo $collection_addr >> $user_file_directory
        echo "Collection address appended to user file $user_file_directory"

    fi

# sh use.sh deploy-nft [net] [collection_addr] [nft_index] [json_filename]
elif [ $1 = "deploy-nft" ]; then

    action_name=$1
    net=$2
    collection_addr=$3
    nft_index=$4
    json_filename=$5

    get_addr_from_file src/build/wallet/deploy-wallet.addr deploy_wallet_addr # get deploy-wallet addr and saves it to $deploy_wallet_addr
    $path_to_fift_binaries -I $fift_libs -L $fift_cli -s src/message-bodies/deploy-nft.fif $deploy_wallet_addr $deploy_wallet_addr $json_filename $nft_index # Create boc-file of message body
    get_seqno_by_addr $net $deploy_wallet_addr deploy_wallet_seqno
    $path_to_fift_binaries -I $fift_libs -s src/external-to-wallet.fif plane_garage_wallet $collection_addr $deploy_wallet_seqno .05 -B src/build/messages/bodies/deploy-nft.boc -n src/build/messages/deploy-nft-full # Add message body to message and create boc-file of full message
    msg_directory="src/build/messages/deploy-nft-full.boc"
    send_boc $net $msg_directory $action_name

# sh use.sh edit-collection [net] [collection_addr] [new_base_uri] [new_collection_uri] [new_royalty_numerator]
elif [ $1 = "edit-collection" ]; then

    action_name=$1
    net=$2
    collection_addr=$3
    new_base_uri=$4
    new_collection_uri=$5
    new_royalty_numerator=$6

    get_addr_from_file src/build/wallet/deploy-wallet.addr deploy_wallet_addr # get deploy-wallet addr and saves it to $deploy_wallet_addr
    $path_to_fift_binaries -I $fift_libs -L $fift_cli -s src/message-bodies/edit-collection.fif $new_base_uri $new_collection_uri $new_royalty_numerator $deploy_wallet_addr # Create boc-file of message body
    get_seqno_by_addr $net $deploy_wallet_addr deploy_wallet_seqno
    $path_to_fift_binaries -I $fift_libs -s src/external-to-wallet.fif plane_garage_wallet $collection_addr $deploy_wallet_seqno .05 -B src/build/messages/bodies/edit-collection.boc -n src/build/messages/edit-collection-full # Add message body to message and create boc-file of full message
    msg_directory="src/build/messages/edit-collection-full.boc"
    send_boc $net $msg_directory $action_name

# sh use.sh edit-nft [net] [nft_addr] [new_cid]
elif [ $1 = "edit-nft" ]; then

    action_name=$1
    net=$2
    nft_addr=$3
    new_cid=$4

    $path_to_fift_binaries -I $fift_libs -L $fift_cli -s src/message-bodies/edit-nft.fif $new_cid # Create boc-file of message body
    get_addr_from_file src/build/wallet/deploy-wallet.addr deploy_wallet_addr # get deploy-wallet addr and saves it to $deploy_wallet_addr
    get_seqno_by_addr $net $deploy_wallet_addr deploy_wallet_seqno
    $path_to_fift_binaries -I $fift_libs -s src/external-to-wallet.fif plane_garage_wallet $nft_addr $deploy_wallet_seqno .01 -B src/build/messages/bodies/edit-nft.boc -n src/build/messages/edit-nft-full # Add message body to message and create boc-file of full message
    msg_directory="src/build/messages/edit-nft-full.boc"
    send_boc $net $msg_directory $action_name

# sh use.sh transfer-nft [net] [nft_addr] [new_owner]
# sh use.sh transfer-nft testnet EQD9T_-01dCe6BevqFJOGOkJaQe7iO07Ylp2-sKxq01td5Zt EQD57OL7n9KjwN5vxrW5KOJ-WIQTEw85mSMXmkdcSS_eLzi7
elif [ $1 = "transfer-nft" ]; then

    action_name=$1
    net=$2
    nft_addr=$3
    new_owner=$4

    $path_to_fift_binaries -I $fift_libs -L $fift_cli -s src/message-bodies/transfer-nft.fif $new_owner # Create boc-file of message body
    get_addr_from_file src/build/wallet/deploy-wallet.addr deploy_wallet_addr # get deploy-wallet addr and saves it to $deploy_wallet_addr
    get_seqno_by_addr $net $deploy_wallet_addr deploy_wallet_seqno
    $path_to_fift_binaries -I $fift_libs -s src/external-to-wallet.fif plane_garage_wallet $nft_addr $deploy_wallet_seqno .01 -B src/build/messages/bodies/transfer-nft.boc -n src/build/messages/transfer-nft-full # Add message body to message and create boc-file of full message
    msg_directory="src/build/messages/transfer-nft-full.boc"
    send_boc $net $msg_directory $action_name

elif [ $1 = "compile-testgiver" ]; then

    $path_to_fift_binaries -I $fift_libs -L $fift_cli -s src/new-testgiver.fif -1  # Create boc-file of message body

elif [ $1 = "deploy-testgiver" ]; then

    action_name=$1

    msg_directory="src/build/testgiver/new-testgiver.boc"
    send_boc testnet $msg_directory $action_name

elif [ $1 = "get-from-testgiver" ]; then

    action_name=$1
    testgiver_addr=$2
    amount=$3

    get_addr_from_file src/build/wallet/deploy-wallet.addr deploy_wallet_addr # get deploy-wallet addr and saves it to $deploy_wallet_addr
    get_seqno_by_addr testnet $testgiver_addr testgiver_seqno
    $path_to_fift_binaries -I $fift_libs -L $fift_cli -s src/testgiver.fif $deploy_wallet_addr $testgiver_seqno $amount # Create boc-file of message body
    msg_directory="src/build/testgiver/testgiver-query.boc"
    send_boc testnet $msg_directory $action_name

# Wrong first argument
else
    echo "First argument is wrong! Please look readme.md"
fi