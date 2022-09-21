#!/usr/bin/env bash

# Скачать бинарники (пребилды) func, fift и lite-client можно тут: https://github.com/ton-blockchain/ton/actions?query=branch%3Amaster+is%3Acompleted

# Пути к бинарникам func и fift (надо указать свои). 
path_to_func_binaries=/Users/vsevolodignatev/Desktop/Projects/ton-macos-binaries/crypto/func # func
path_to_fift_binaries=/Users/vsevolodignatev/Desktop/Projects/ton-macos-binaries/crypto/fift # fift
path_to_lite_client_binaries=/Users/vsevolodignatev/Desktop/Projects/ton-macos-binaries/lite-client/lite-client # lite-client


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