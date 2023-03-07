fx_version 'cerulean'
game 'gta5'

name "ESX Taxi Job"
description "The Most Advanced and feature-rich Taxi System."
author "Mycroft & ESX-Framework"
legacyversion '1.9.3'
lua54 'yes'
version "2.0.0"

shared_scripts {
	'@es_extended/locale.lua',
	'@es_extended/imports.lua',
	'shared/*.lua'
}

client_scripts {
	'client/*.lua'
}

server_scripts {
	'server/*.lua'
}

dependency 'es_extended'