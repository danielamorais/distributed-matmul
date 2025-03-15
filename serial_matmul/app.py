from flask import Flask, request, jsonify
import ast

app = Flask(__name__)

def multiply_matrices(A, B):
    rows_A = len(A)
    cols_A = len(A[0])
    cols_B = len(B[0])

    # Cria matriz resultado preenchida com zeros
    result = [[0 for _ in range(cols_B)] for _ in range(rows_A)]

    for i in range(rows_A):
        for j in range(cols_B):
            for k in range(cols_A):
                result[i][j] += A[i][k] * B[k][j]
    return result

@app.route('/matmul', methods=['POST'])
def handle_multiply():
    data = request.get_json()
    
    # Verifica dados de entrada
    if not data or 'A' not in data or 'B' not in data:
        return jsonify({"error": "Formato inválido. Forneça matrizes A e B."}), 400

    try:
        # Converte strings para matrizes
        matrix_A = ast.literal_eval(data['A'])
        matrix_B = ast.literal_eval(data['B'])
    except Exception as e:
        return jsonify({"error": f"Formato de matriz inválido: {str(e)}"}), 400

    # Valida formato das matrizes
    if (not all(len(row) == len(matrix_A[0]) for row in matrix_A)) or \
       (not all(len(row) == len(matrix_B[0]) for row in matrix_B)):
        return jsonify({"error": "Matrizes devem ter linhas de tamanho uniforme"}), 400

    # Verifica se multiplicação é possível
    if len(matrix_A[0]) != len(matrix_B):
        return jsonify({"error": "Número de colunas de A deve ser igual ao número de linhas de B"}), 400

    try:
        result = multiply_matrices(matrix_A, matrix_B)
    except Exception as e:
        return jsonify({"error": f"Erro na multiplicação: {str(e)}"}), 500

    return jsonify({"resultado": result})

if __name__ == '__main__':
    app.run(debug=True)
