import json
import dash
from dash import dcc, html
from dash.dependencies import Input, Output
import math
import dash_bootstrap_components as dbc

# Carrega dados JSON do arquivo
try:
    with open('test 3.json', 'r', encoding='utf-8-sig') as f:  # troca pelo nome do seu json
        data = json.load(f)
except json.JSONDecodeError as e:
    print(f"Erro ao ler arquivo JSON: {e}")
    data = {"Folders": {}, "Groups": {}}
except FileNotFoundError:
    print("Arquivo JSON não encontrado")
    data = {"Folders": {}, "Groups": {}}

# Prepara dados para visualização
folders_data = data['Folders']
groups_data = data['Groups']

# Converte dados de pastas para um formato mais amigável
folder_options = []
folder_group_map = {}
for folder_name, folder_details in folders_data.items():
    folder_options.append({'label': folder_name, 'value': folder_name})
    folder_group_map[folder_name] = folder_details.get('Groups', [])

# Converte dados de grupos para um formato mais amigável
group_options = []
for group_name, group_details in groups_data.items():
    group_options.append({'label': group_name, 'value': group_name})

# Inicializa aplicação Dash
app = dash.Dash(__name__)

def get_rights_class(rights):
    rights = str(rights).lower()
    if 'full' in rights:
        return 'full'
    elif 'modify' in rights:
        return 'modify'
    else:
        return 'read'

# CSS para estilização
app.index_string = '''
<!DOCTYPE html>
<html>
    <head>
        {%metas%}
        <title>Explorador de Permissões de Pastas</title>
        {%favicon%}
        {%css%}
        <style>
            body {
                font-family: 'Segoe UI', -apple-system, BlinkMacSystemFont, Roboto, Oxygen, Ubuntu, sans-serif;
                background-color: #f8f9fa;
                margin: 0;
                padding: 20px;
                color: #2c3e50;
            }
            
            .app-container {
                max-width: 1200px;
                margin: 0 auto;
                background: white;
                border-radius: 12px;
                box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
                padding: 25px;
            }
            
            .page-title {
                text-align: center;
                color: #2c3e50;
                font-size: 2.2em;
                margin-bottom: 30px;
                padding-bottom: 15px;
                border-bottom: 3px solid #3498db;
            }
            
            .tab-content {
                padding: 25px;
                background: white;
                border-radius: 8px;
            }
            
            .dropdown {
                margin-bottom: 25px;
                font-size: 16px;
            }
            
            .section-header {
                color: #2c3e50;
                font-size: 1.5em;
                margin: 25px 0 15px 0;
                padding-bottom: 10px;
                border-bottom: 2px solid #eee;
            }
            
            .table-responsive {
                margin-top: 20px;
                border-radius: 8px;
                box-shadow: 0 2px 4px rgba(0,0,0,0.05);
                overflow-x: auto;
                background: white;
                border: 1px solid #e0e0e0;
            }
            
            .table {
                margin-bottom: 0;
                width: 100%;
                border-collapse: separate;
                border-spacing: 0;
            }
            
            .table th {
                background-color: #f8f9fa;
                border-bottom: 2px solid #dee2e6;
                padding: 15px;
                font-weight: 600;
                color: #2c3e50;
                text-transform: uppercase;
                font-size: 0.9em;
                letter-spacing: 0.5px;
            }
            
            .table td {
                padding: 12px 15px;
                vertical-align: middle;
                border-bottom: 1px solid #dee2e6;
                transition: background-color 0.2s;
            }
            
            .table tr:hover td {
                background-color: #f8f9fa;
            }
            
            .rights-cell {
                min-width: 120px;
                padding: 6px 12px;
                border-radius: 4px;
                font-weight: 500;
                display: inline-block;
                text-align: center;
                transition: all 0.2s;
            }
            
            .rights-full {
                background-color: #e8f5e9;
                color: #2e7d32;
                border: 1px solid #a5d6a7;
            }
            
            .rights-modify {
                background-color: #fff3e0;
                color: #ef6c00;
                border: 1px solid #ffcc80;
            }
            
            .rights-read {
                background-color: #e3f2fd;
                color: #1976d2;
                border: 1px solid #90caf9;
            }
            
            .user-list {
                max-height: 500px;
                overflow-y: auto;
                border: 1px solid #e0e0e0;
                border-radius: 6px;
                padding: 15px;
                background: white;
                margin: 10px 0;
            }
            
            .user-list li {
                padding: 8px 12px;
                border-bottom: 1px solid #eee;
                transition: background-color 0.2s;
            }
            
            .user-list li:last-child {
                border-bottom: none;
            }
            
            .user-list li:hover {
                background-color: #f8f9fa;
            }
            
            .disabled-user {
                color: #e74c3c;
                background-color: #fde8e8;
                padding: 8px 12px;
                border-radius: 4px;
                border: 1px solid #fad2d2;
            }
            
            .stat-box {
                background: #f8f9fa;
                padding: 12px 20px;
                border-radius: 6px;
                color: #2c3e50;
                font-weight: 500;
                display: inline-block;
                border: 1px solid #e0e0e0;
            }
            
            /* Barra de rolagem personalizada */
            ::-webkit-scrollbar {
                width: 8px;
                height: 8px;
            }
            
            ::-webkit-scrollbar-track {
                background: #f1f1f1;
                border-radius: 4px;
            }
            
            ::-webkit-scrollbar-thumb {
                background: #c1c1c1;
                border-radius: 4px;
            }
            
            ::-webkit-scrollbar-thumb:hover {
                background: #a8a8a8;
            }
        </style>
    </head>
    <body>
        {%app_entry%}
        <footer>
            {%config%}
            {%scripts%}
            {%renderer%}
        </footer>
    </body>
</html>
'''

# Layout da aplicação
app.layout = html.Div([
    html.H1("Explorador de Permissões de Pastas", className='page-title'),
    html.Div([
        dcc.Tabs([
            dcc.Tab(label='Pastas', children=[
                html.Div([
                    html.H2("Selecione uma Pasta", style={'color': '#2c3e50'}),
                    dcc.Dropdown(
                        id='folder-dropdown',
                        options=folder_options,
                        multi=False,
                        placeholder="Selecione uma pasta...",
                        className='dropdown'
                    ),
                    html.Div(id='folder-groups-output'),
                ], className='tab-content'),
            ]),
            dcc.Tab(label='Grupos', children=[
                html.Div([
                    html.H2("Selecione um Grupo", style={'color': '#2c3e50'}),
                    dcc.Dropdown(
                        id='group-dropdown',
                        options=group_options,
                        multi=False,
                        placeholder="Selecione um grupo...",
                        className='dropdown'
                    ),
                    html.Div(id='group-users-output'),
                ], className='tab-content'),
            ]),
        ], style={
            'marginTop': '20px',
            'borderRadius': '8px',
            'overflow': 'hidden'
        }),
    ], className='app-container')
])

# Callback para exibir grupos associados a uma pasta
@app.callback(
    Output('folder-groups-output', 'children'),
    [Input('folder-dropdown', 'value')]
)
def update_folder_groups(selected_folder):
    if selected_folder:
        groups = folder_group_map.get(selected_folder, [])
        if groups:
            return html.Div([
                html.H3(f"Grupos com acesso à pasta '{selected_folder}':", 
                       className='section-header'),
                html.Div([
                    dbc.Table(
                        [
                            html.Thead(html.Tr([
                                html.Th("Nome do Grupo", style={'width': '60%'}),
                                html.Th("Direitos de Acesso", style={'width': '40%'})
                            ])),
                            html.Tbody([
                                html.Tr([
                                    html.Td(group['Name']),
                                    html.Td(
                                        html.Div(
                                            group.get('Rights', 'N/D'),
                                            className=f"rights-cell rights-{get_rights_class(group.get('Rights', ''))}"
                                        )
                                    )
                                ]) for group in sorted(groups, key=lambda x: x['Name'])
                            ])
                        ],
                        bordered=True,
                        hover=True,
                        striped=True,
                        className='table-sm'
                    )
                ], className='table-responsive'),
                html.Div(
                    f"Total de Grupos: {len(groups)}", 
                    className='stat-box',
                    style={'marginTop': '15px'}
                )
            ])
        else:
            return html.Div(f"Nenhum grupo encontrado para a pasta '{selected_folder}'.")
    else:
        return html.Div("Selecione uma pasta para ver os grupos associados.")

# Callback para exibir usuários em um grupo
@app.callback(
    Output('group-users-output', 'children'),
    [Input('group-dropdown', 'value')]
)
def update_group_users(selected_group):
    if selected_group:
        group_data = groups_data.get(selected_group)
        if group_data and group_data.get('Users'):
            users = group_data['Users']
            
            # Divide usuários em ativos e desativados
            active_users = []
            disabled_users = []
            
            for user in users:
                is_disabled = not user.get('Enabled', True)
                if is_disabled:
                    disabled_users.append(user)
                else:
                    active_users.append(user)
            
            # Cria itens de lista para usuários ativos
            active_user_items = [html.Li(user['DisplayName']) for user in active_users]
            
            # Cria itens de lista para usuários desativados
            disabled_user_items = [
                html.Li(user['DisplayName'] + " (DESATIVADO)", className='disabled-user') 
                for user in disabled_users
            ]
            
            # Constrói a saída completa com usuários ativos primeiro, depois desativados
            output_elements = [html.H3(f"Usuários no grupo '{selected_group}':")]
            
            if active_user_items:
                output_elements.extend([
                    html.Div("Usuários Ativos:", className='section-header'),
                    html.Div(html.Ul(active_user_items), className='user-list')
                ])
            
            if disabled_user_items:
                output_elements.extend([
                    html.Div("Usuários Desativados:", className='section-header'),
                    html.Div(html.Ul(disabled_user_items), className='user-list')
                ])
                
            return html.Div(output_elements)
        else:
            return html.Div(f"Nenhum usuário encontrado para o grupo '{selected_group}'.")
    else:
        return html.Div("Selecione um grupo para ver os usuários.")

# Executa a aplicação
if __name__ == '__main__':
    app.run_server(debug=False, host='0.0.0.0', port=8050)
