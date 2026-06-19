fx_version 'cerulean'
game 'gta5'

name 'esx_multicharacter'
author 'LEXIKON'
description 'Multicharacter for ESX Legacy 1.13.5 '
version '1.0.0'
repository 'https://github.com/LEXIKON-Dev/esx-kashacter/'
lua54 'yes'

dependencies {
	'es_extended',
	'oxmysql',
	'esx_menu_default',
	'esx_identity',
	'esx_skin',
	'skinchanger',
}

shared_scripts {
	'@es_extended/locale.lua',
	'locales/*.lua',
	'config.lua'
}

server_scripts {
	'@es_extended/imports.lua',
	'@oxmysql/lib/MySQL.lua',
	'server/*.lua',
}

client_scripts {
	'client/*.lua'
}

ui_page {
	'html/ui.html',
}

files {
	'html/ui.html',
	'html/css/main.css',
	'html/js/app.js',
}
