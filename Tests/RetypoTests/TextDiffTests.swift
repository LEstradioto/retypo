import XCTest
@testable import Retypo

final class TextDiffTests: XCTestCase {
    private func edits(_ original: String, _ revised: String) -> [TextDiff.Segment] {
        TextDiff(original: original, revised: revised).segments.filter(\.isEdit)
    }

    private func tinted(_ diff: TextDiff) -> [String] {
        diff.marks.added.map { (diff.revised as NSString).substring(with: $0) }
    }

    func testIdenticalTextHasNoEdits() {
        let diff = TextDiff(original: "hello world", revised: "hello world")
        XCTAssertEqual(diff.segments, [.kept("hello world")])
        XCTAssertEqual(diff.editCount, 0)
        XCTAssertFalse(diff.hasEdits)
    }

    func testEmptyTextsHaveNoSegments() {
        XCTAssertEqual(TextDiff.none.segments, [])
        XCTAssertEqual(TextDiff(original: "", revised: "").marks, ChangeMarks())
    }

    func testSingleWordReplacementTintsOnlyThatWord() {
        let diff = TextDiff(original: "the cat sat", revised: "the dog sat")
        XCTAssertEqual(diff.segments, [.kept("the "), .edit(removed: "cat", added: "dog"), .kept(" sat")])
        XCTAssertEqual(tinted(diff), ["dog"])
    }

    func testInsertedWordIsTintedWithoutItsSpace() {
        let diff = TextDiff(original: "the sat", revised: "the cat sat")
        XCTAssertEqual(diff.editCount, 1)
        XCTAssertEqual(tinted(diff), ["cat"])
    }

    /// The old diff compared lowercased words only, so these were invisible.
    func testPunctuationAndCaseAreEdits() {
        XCTAssertEqual(edits("hello world", "hello world!"), [.edit(removed: "", added: "!")])
        XCTAssertEqual(edits("nossa IA", "Nossa IA"), [.edit(removed: "nossa", added: "Nossa")])
        XCTAssertEqual(edits("valor, e", "valor. e"), [.edit(removed: ",", added: ".")])
    }

    /// The old diff could only point at new text; a removal left no trace.
    func testRemovedPhraseLeavesARemovalPoint() {
        let diff = TextDiff(original: "a estimativa de economia apresentada", revised: "a estimativa apresentada")
        XCTAssertEqual(diff.segments.filter(\.isEdit), [.edit(removed: " de economia", added: "")])
        XCTAssertEqual(diff.marks.removals, [("a estimativa" as NSString).length])
        XCTAssertEqual(diff.marks.added, [])
    }

    func testReplacedWordsAreOneEdit() {
        XCTAssertEqual(edits("Agradecemos o contato", "Obrigado pelo contato"), [.edit(removed: "Agradecemos o", added: "Obrigado pelo")])
        XCTAssertEqual(edits("o valor que poderá ser recuperado.", "o valor envolvido nas glosas."),
                       [.edit(removed: "que poderá ser recuperado", added: "envolvido nas glosas")])
    }

    /// A word both rewrites happen to share ("o") would split the edit in
    /// two; shorter than both sides, it joins them.
    func testShortStretchesBetweenEditsJoinThem() {
        XCTAssertEqual(edits("vamos ver o resultado amanhã", "quero checar o relatório hoje"),
                       [.edit(removed: "vamos ver o resultado amanhã", added: "quero checar o relatório hoje")])
    }

    /// Aligning spaces as tokens once kept a space instead of the word.
    func testAlignmentKeepsWordsOverSpaces() {
        XCTAssertEqual(edits("a estimativa de economia apresentada", "a nova estimativa apresentada"),
                       [.edit(removed: "", added: " nova"), .edit(removed: " de economia", added: "")])
    }

    /// A removed paragraph takes its own line break, not the next one's.
    func testRemovedSentenceKeepsTheParagraphBreak() {
        XCTAssertEqual(TextDiff(original: "Primeiro.\n\nRemovido aqui. Fica.", revised: "Primeiro.\n\nFica.").segments,
                       [.kept("Primeiro.\n\n"), .edit(removed: "Removido aqui. ", added: ""), .kept("Fica.")])
    }

    func testEditsInTwoParagraphsNeverJoin() {
        let found = edits("um dois\n\ntres quatro", "um 2\n\n3 quatro")
        XCTAssertEqual(found, [.edit(removed: "dois", added: "2"), .edit(removed: "tres", added: "3")])
    }

    func testDistantEditsStaySeparate() {
        XCTAssertEqual(TextDiff(original: "the cat sat on the mat", revised: "the dog sat on the rug").editCount, 2)
    }

    /// Replies come back trimmed; the draft's trailing newline is no edit.
    func testWhitespaceOnlyEditsAtTheEdgesAreNotChanges() {
        XCTAssertFalse(TextDiff(original: "Hello\n", revised: "Hello").hasEdits)
        XCTAssertFalse(TextDiff(original: "  Hello", revised: "Hello").hasEdits)
        XCTAssertTrue(TextDiff(original: "a  b", revised: "a b").hasEdits, "a double space inside is a real fix")
    }

    func testEverythingRemovedIsOneRemoval() {
        let diff = TextDiff(original: "anything", revised: "")
        XCTAssertEqual(diff.segments, [.edit(removed: "anything", added: "")])
        XCTAssertEqual(diff.marks.removals, [0])
    }

    func testRangesCountUTF16LikeTheEditor() {
        let diff = TextDiff(original: "café ☕️ bom 👍", revised: "café ☕️ ótimo 👍")
        XCTAssertEqual(tinted(diff), ["ótimo"])
    }

    /// The reply that motivated the rewrite, with its content swapped out:
    /// every removal shows, not only the new words.
    func testRewrittenReplyShowsEveryEdit() {
        let original = "Olá! Agradecemos o contato. Desculpe a demora.\n\nO Atlas é um aplicativo que ajuda clínicas a organizar a agenda.\n\nNa prática, lemos a agenda do portal, organizamos tudo por horário e sala, e nossa IA sugere encaixes. Você revisa e aprova.\n\nO valor é definido de acordo com a estimativa de economia apresentada no teste.\n\n(Reescreva e melhore)"
        let revised = "Olá! Obrigado pelo contato. Desculpe a demora.\n\nO Atlas é um aplicativo independente que ajuda clínicas a organizar a agenda.\n\nNa prática, lemos a agenda do portal e organizamos tudo por horário e sala. Nossa IA sugere encaixes. Você revisa e aprova.\n\nO valor é definido de acordo com a estimativa apresentada no teste."
        let diff = TextDiff(original: original, revised: revised)
        XCTAssertEqual(diff.segments.filter(\.isEdit), [
            .edit(removed: "Agradecemos o", added: "Obrigado pelo"),
            .edit(removed: "", added: " independente"),
            .edit(removed: ",", added: " e"),
            .edit(removed: ", e nossa", added: ". Nossa"),
            .edit(removed: " de economia", added: ""),
            .edit(removed: "\n\n(Reescreva e melhore)", added: "")
        ])
        XCTAssertEqual(diff.marks.removals.count, 2)
        XCTAssertEqual(diff.revised, revised)
    }

    func testKeptAndAddedTextRebuildTheRevision() {
        let diff = TextDiff(original: "Uma frase, com vírgula.\nOutra linha", revised: "Uma frase com ponto.\n\nOutra linha nova")
        let rebuilt = diff.segments.map { segment -> String in
            switch segment {
            case .kept(let text): text
            case .edit(_, let added): added
            }
        }.joined()
        XCTAssertEqual(rebuilt, diff.revised)
    }
}
