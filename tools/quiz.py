"""Small offline terminal practice runner."""
import argparse
import json
import random
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--lab', required=True, choices=[f'{i:02}' for i in range(1,21)])
    parser.add_argument('--shuffle', action='store_true')
    parser.add_argument('--seed', type=int)
    parser.add_argument('--limit', type=int, default=30, choices=range(1,31))
    args = parser.parse_args()
    folder = next((ROOT / 'labs').glob(f'{args.lab}-*'))
    questions = json.loads((folder / 'questions.json').read_text(encoding='utf-8'))
    if args.shuffle:
        random.Random(args.seed).shuffle(questions)
    questions = questions[:args.limit]
    score = 0
    try:
        for number, question in enumerate(questions,1):
            print(f'\n{number}/{len(questions)} [{question["id"]}] {question["stem"]}')
            for letter, choice in sorted(question['choices'].items()):
                print(f'  {letter}. {choice}')
            answer = input('Answer A–D (Q to quit): ').strip().upper()
            while answer not in 'ABCD' or len(answer) != 1:
                if answer == 'Q':
                    return
                answer = input('Enter A, B, C, D, or Q: ').strip().upper()
            score += answer == question['answer']
            print(f'Correct answer: {question["answer"]}')
            for letter, explanation in sorted(question['explanations'].items()):
                print(f'  {letter}: {explanation}')
            print(f'Review: {folder.relative_to(ROOT)}/{question["remediation"]}')
        print(f'\nScore: {score}/{len(questions)} ({score/len(questions):.0%}). Revisit missed objectives before retrying.')
    except (EOFError, KeyboardInterrupt):
        print('\nPractice ended; no progress file written.')


if __name__ == '__main__':
    main()
