import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mideas_touch_creator/src/catalog.dart';
import 'package:mideas_touch_creator/src/models.dart';
import 'package:mideas_touch_creator/src/template_repository.dart';

class CreatorState {
  const CreatorState({
    required this.splash,
    required this.themeMode,
    required this.language,
    required this.authTab,
    required this.name,
    required this.email,
    required this.password,
    required this.agreed,
    required this.user,
    required this.view,
    required this.filter,
    required this.designs,
    required this.current,
    required this.editingId,
    required this.publishedDesign,
    required this.selected,
    required this.history,
    required this.future,
    required this.tool,
    required this.imageQuery,
    required this.removingBackground,
    required this.showGuide,
    required this.formTick,
    required this.toastMessage,
    required this.toastTick,
    required this.publishing,
  });

  factory CreatorState.initial() {
    return const CreatorState(
      splash: true,
      themeMode: ThemeMode.system,
      language: 'en',
      authTab: AuthTab.register,
      name: '',
      email: '',
      password: '',
      agreed: false,
      user: null,
      view: StudioView.create,
      filter: DesignFilter.all,
      designs: [],
      current: null,
      editingId: null,
      publishedDesign: null,
      selected: -1,
      history: [],
      future: [],
      tool: EditorTool.text,
      imageQuery: '',
      removingBackground: false,
      showGuide: false,
      formTick: 0,
      toastMessage: null,
      toastTick: 0,
      publishing: false,
    );
  }

  final bool splash;
  final ThemeMode themeMode;
  final String language;
  final AuthTab authTab;
  final String name;
  final String email;
  final String password;
  final bool agreed;
  final StudioUser? user;
  final StudioView view;
  final DesignFilter filter;
  final List<Design> designs;
  final Design? current;
  final int? editingId;
  final Design? publishedDesign;
  final int selected;
  final List<EditorSnapshot> history;
  final List<EditorSnapshot> future;
  final EditorTool? tool;
  final String imageQuery;
  final bool removingBackground;
  final bool showGuide;
  final int formTick;
  final String? toastMessage;
  final int toastTick;
  final bool publishing;

  bool get canUndo => history.isNotEmpty;
  bool get canRedo => future.isNotEmpty;

  bool get updatingPublished {
    final id = editingId;
    if (id == null) return false;
    for (final design in designs) {
      if (design.id == id && design.status == DesignStatus.published) return true;
    }
    return false;
  }

  List<Design> get visibleDesigns {
    switch (filter) {
      case DesignFilter.all:
        return designs;
      case DesignFilter.published:
        return designs.where((design) => design.status == DesignStatus.published).toList();
      case DesignFilter.drafts:
        return designs.where((design) => design.status == DesignStatus.draft).toList();
    }
  }

  CreatorState copyWith({
    bool? splash,
    ThemeMode? themeMode,
    String? language,
    AuthTab? authTab,
    String? name,
    String? email,
    String? password,
    bool? agreed,
    StudioUser? user,
    bool clearUser = false,
    StudioView? view,
    DesignFilter? filter,
    List<Design>? designs,
    Design? current,
    bool clearCurrent = false,
    int? editingId,
    bool clearEditing = false,
    Design? publishedDesign,
    int? selected,
    List<EditorSnapshot>? history,
    List<EditorSnapshot>? future,
    EditorTool? tool,
    bool clearTool = false,
    String? imageQuery,
    bool? removingBackground,
    bool? showGuide,
    int? formTick,
    String? toastMessage,
    int? toastTick,
    bool? publishing,
  }) {
    return CreatorState(
      splash: splash ?? this.splash,
      themeMode: themeMode ?? this.themeMode,
      language: language ?? this.language,
      authTab: authTab ?? this.authTab,
      name: name ?? this.name,
      email: email ?? this.email,
      password: password ?? this.password,
      agreed: agreed ?? this.agreed,
      user: clearUser ? null : (user ?? this.user),
      view: view ?? this.view,
      filter: filter ?? this.filter,
      designs: designs ?? this.designs,
      current: clearCurrent ? null : (current ?? this.current),
      editingId: clearEditing ? null : (editingId ?? this.editingId),
      publishedDesign: publishedDesign ?? this.publishedDesign,
      selected: selected ?? this.selected,
      history: history ?? this.history,
      future: future ?? this.future,
      tool: clearTool ? null : (tool ?? this.tool),
      imageQuery: imageQuery ?? this.imageQuery,
      removingBackground: removingBackground ?? this.removingBackground,
      showGuide: showGuide ?? this.showGuide,
      formTick: formTick ?? this.formTick,
      toastMessage: toastMessage ?? this.toastMessage,
      toastTick: toastTick ?? this.toastTick,
      publishing: publishing ?? this.publishing,
    );
  }
}

class CreatorCubit extends Cubit<CreatorState> {
  CreatorCubit({TemplateRepository? templates})
      : _templates = templates ?? SupabaseTemplateRepository(),
        super(CreatorState.initial());

  final TemplateRepository _templates;
  final ImagePicker _picker = ImagePicker();
  bool _live = false;
  Timer? _liveTimer;
  int _removeToken = 0;
  EditorSnapshot? _gestureBefore;

  void dismissSplash() {
    if (!state.splash) return;
    emit(state.copyWith(splash: false));
  }

  void toggleTheme({required bool currentlyDark}) {
    emit(state.copyWith(themeMode: currentlyDark ? ThemeMode.light : ThemeMode.dark));
  }

  void setLanguage(String language) => emit(state.copyWith(language: language));

  void setAuthTab(AuthTab tab) => emit(state.copyWith(authTab: tab));

  void setName(String value) => emit(state.copyWith(name: value));

  void setEmail(String value) => emit(state.copyWith(email: value));

  void setPassword(String value) => emit(state.copyWith(password: value));

  void setAgreed(bool value) => emit(state.copyWith(agreed: value));

  void submitAuth() {
    final register = state.authTab == AuthTab.register;
    if (register && state.name.trim().isEmpty) {
      toast('Enter your full name');
      return;
    }
    if (!RegExp(r'\S+@\S+\.\S+').hasMatch(state.email)) {
      toast('Enter a valid email');
      return;
    }
    if (state.password.length < 6) {
      toast('Password must be 6+ characters');
      return;
    }
    if (register && !state.agreed) {
      toast('Please accept the creator terms');
      return;
    }
    final user = StudioUser(
      name: state.name.trim().isEmpty ? 'Creator' : state.name.trim(),
      email: state.email,
    );
    emit(state.copyWith(user: user));
    newDesign();
    toast(register ? 'Creator account created' : 'Welcome back');
  }

  void forgotPassword() => toast('Reset link sent');

  void logout() {
    _cancelAsync();
    emit(state.copyWith(
      clearUser: true,
      clearCurrent: true,
      clearEditing: true,
      password: '',
      authTab: AuthTab.login,
      selected: -1,
      clearTool: true,
      removingBackground: false,
      showGuide: false,
    ));
  }

  void newDesign() {
    _cancelAsync();
    final base = Catalog.templates.first;
    final created = base.copyWith(
      id: DateTime.now().millisecondsSinceEpoch,
      name: '',
      description: '',
      elements: [...base.elements],
      status: '',
      savedAt: '',
    );
    emit(state.copyWith(
      current: created,
      clearEditing: true,
      view: StudioView.create,
      history: const [],
      future: const [],
      selected: -1,
      tool: EditorTool.text,
      removingBackground: false,
      showGuide: false,
      formTick: state.formTick + 1,
    ));
  }

  void openMine() => emit(state.copyWith(view: StudioView.mine));

  void setFilter(DesignFilter filter) => emit(state.copyWith(filter: filter));

  void editDesign(int id) {
    Design? source;
    for (final design in state.designs) {
      if (design.id == id) source = design;
    }
    if (source == null) return;
    _cancelAsync();
    emit(state.copyWith(
      current: source.copyWith(elements: [...source.elements]),
      editingId: id,
      view: StudioView.create,
      history: const [],
      future: const [],
      selected: -1,
      clearTool: true,
      removingBackground: false,
      showGuide: false,
      formTick: state.formTick + 1,
    ));
  }

  void setDesignName(String name) {
    final current = state.current;
    if (current == null || current.name == name) return;
    emit(state.copyWith(current: current.copyWith(name: name)));
  }

  void setCategory(String category) {
    final current = state.current;
    if (current == null) return;
    emit(state.copyWith(
      current: current.copyWith(category: category),
      formTick: state.formTick + 1,
    ));
  }

  void setImageQuery(String value) => emit(state.copyWith(imageQuery: value));

  void toggleTool(EditorTool tool) {
    final next = state.tool == tool ? null : tool;
    emit(state.copyWith(
      tool: next,
      clearTool: next == null,
      selected: -1,
      formTick: state.formTick + 1,
    ));
  }

  void clearSelection() {
    if (state.selected < 0) return;
    emit(state.copyWith(selected: -1, showGuide: false, formTick: state.formTick + 1));
  }

  void beginGesture(int index) {
    final current = state.current;
    if (current == null) return;
    _gestureBefore = _snap(current);
    emit(state.copyWith(selected: index, formTick: state.formTick + 1));
  }

  void previewElement(int index, DesignElement element, {required bool guide}) {
    final current = state.current;
    if (current == null || index < 0 || index >= current.elements.length) return;
    final elements = [...current.elements];
    elements[index] = element;
    emit(state.copyWith(
      current: current.copyWith(elements: elements),
      showGuide: guide,
    ));
  }

  void endGesture({required bool moved}) {
    final before = _gestureBefore;
    _gestureBefore = null;
    if (moved && before != null && state.current != null) {
      emit(state.copyWith(
        history: [...state.history, before],
        future: const [],
        showGuide: false,
        formTick: state.formTick + 1,
      ));
      return;
    }
    if (state.showGuide) {
      emit(state.copyWith(showGuide: false));
    }
  }

  void undo() {
    final current = state.current;
    if (current == null || state.history.isEmpty) return;
    _cancelAsync();
    final history = [...state.history];
    final snap = history.removeLast();
    emit(state.copyWith(
      current: _restore(current, snap),
      history: history,
      future: [_snap(current), ...state.future],
      selected: -1,
      removingBackground: false,
      showGuide: false,
      formTick: state.formTick + 1,
    ));
  }

  void redo() {
    final current = state.current;
    if (current == null || state.future.isEmpty) return;
    _cancelAsync();
    final future = [...state.future];
    final snap = future.removeAt(0);
    emit(state.copyWith(
      current: _restore(current, snap),
      history: [...state.history, _snap(current)],
      future: future,
      selected: -1,
      removingBackground: false,
      showGuide: false,
      formTick: state.formTick + 1,
    ));
  }

  void setHeadline(String value) => _setTextRole(first: true, value: value);

  void setSubtitle(String value) => _setTextRole(first: false, value: value);

  void setSelectedText(String value) {
    final index = state.selected;
    final current = state.current;
    if (current == null || index < 0 || index >= current.elements.length) return;
    if (current.elements[index].kind != ElementKind.text) return;
    _armLive(800);
    _writeElement(index, current.elements[index].copyWith(text: value));
  }

  void setFont(String font) => _updateSelected((element) => element.copyWith(font: font));

  void setFontSize(double size) => _updateSelected((element) => element.copyWith(size: size));

  void bumpFontSize(double delta) {
    _updateSelected((element) => element.copyWith(size: math.max(8, (element.size + delta).roundToDouble())));
  }

  void setTextColor(Color color) => _updateSelected((element) => element.copyWith(color: color));

  void setShapeColor(Color color) => _updateSelected((element) => element.copyWith(fill: color));

  void toggleBold() => _updateSelected((element) => element.copyWith(bold: !element.bold));

  void toggleItalic() => _updateSelected((element) => element.copyWith(italic: !element.italic));

  void toggleUnderline() => _updateSelected((element) => element.copyWith(underline: !element.underline));

  void setAlign(PosterAlign align) => _updateSelected((element) => element.copyWith(align: align));

  void beginLive() => _armLive(0);

  void endLive() {
    _liveTimer?.cancel();
    _live = false;
    emit(state.copyWith(formTick: state.formTick + 1));
  }

  void setWidth(double value) {
    _updateSelected((element) {
      final ratio = element.w == 0 ? 1.0 : value / element.w;
      return element.copyWith(
        w: value,
        h: element.kind == ElementKind.shape ? element.h * ratio : element.h,
        size: element.kind == ElementKind.text ? element.size * ratio : element.size,
      );
    }, record: false, form: false);
  }

  void setHeight(double value) {
    _updateSelected((element) {
      if (element.kind != ElementKind.image) return element;
      return element.copyWith(h: value);
    }, record: false, form: false);
  }

  void setRotation(double value) {
    _updateSelected((element) => element.copyWith(rotation: value), record: false, form: false);
  }

  void deleteSelected() {
    final current = state.current;
    final index = state.selected;
    if (current == null || index < 0 || index >= current.elements.length) return;
    final elements = [...current.elements]..removeAt(index);
    emit(state.copyWith(
      current: current.copyWith(elements: elements),
      history: [...state.history, _snap(current)],
      future: const [],
      selected: -1,
      formTick: state.formTick + 1,
    ));
  }

  void addHeading() {
    _add(const DesignElement.text(
      x: 8,
      y: 44,
      w: 84,
      text: 'Your heading',
      font: 'Poppins',
      size: 40,
      color: Color(0xFFFFFFFF),
      bold: true,
    ));
  }

  void addSubtitle() {
    _add(const DesignElement.text(
      x: 8,
      y: 44,
      w: 84,
      text: 'Add a subtitle',
      font: 'Poppins',
      size: 22,
      color: Color(0xFFFFFFFF),
    ));
  }

  void addEmoji(int index) {
    if (index < 0 || index >= Catalog.stickers.length) return;
    final emoji = Catalog.stickers[index].emoji;
    final current = state.current;
    final selected = state.selected;
    if (current != null &&
        selected >= 0 &&
        selected < current.elements.length &&
        current.elements[selected].kind == ElementKind.image) {
      _updateSelected((element) => element.copyWith(emoji: emoji, imageBytes: null, photo: true));
      return;
    }
    _add(DesignElement.image(x: 35, y: 35, w: 30, emoji: emoji));
  }

  void setMainEmoji(int index) {
    final current = state.current;
    if (current == null || index < 0 || index >= Catalog.stickers.length) return;
    final imageIndex = current.firstImage;
    if (imageIndex == null) return;
    final elements = [...current.elements];
    elements[imageIndex] = elements[imageIndex].copyWith(
      emoji: Catalog.stickers[index].emoji,
      imageBytes: null,
      photo: true,
    );
    emit(state.copyWith(
      current: current.copyWith(elements: elements),
      history: [...state.history, _snap(current)],
      future: const [],
      formTick: state.formTick + 1,
    ));
  }

  void addCircle() {
    _add(const DesignElement.shape(
      x: 30,
      y: 30,
      w: 30,
      h: 30,
      fill: Color(0xFFFDE68A),
      radius: '50%',
    ));
  }

  void addSquare() {
    _add(const DesignElement.shape(
      x: 30,
      y: 30,
      w: 30,
      h: 30,
      fill: Color(0xFFFDE68A),
      radius: '0',
    ));
  }

  void addBar() {
    _add(const DesignElement.shape(
      x: 20,
      y: 40,
      w: 60,
      h: 12,
      fill: Color(0xFFFDE68A),
      radius: '999px',
    ));
  }

  void setBackground(int index) {
    final current = state.current;
    if (current == null || index < 0 || index >= Catalog.backgrounds.length) return;
    final pair = Catalog.backgrounds[index];
    emit(state.copyWith(
      current: current.copyWith(bg1: pair.$1, bg2: pair.$2, backgroundImage: null),
      history: [...state.history, _snap(current)],
      future: const [],
      formTick: state.formTick + 1,
    ));
  }

  void removeUploadedBackground() {
    final current = state.current;
    if (current == null) return;
    emit(state.copyWith(
      current: current.copyWith(backgroundImage: null),
      history: [...state.history, _snap(current)],
      future: const [],
      formTick: state.formTick + 1,
    ));
  }

  void applyTemplate(int id) {
    final current = state.current;
    final template = Catalog.byId(id);
    if (current == null || template == null) return;
    emit(state.copyWith(
      current: current.copyWith(
        bg1: template.bg1,
        bg2: template.bg2,
        backgroundImage: null,
        elements: [...template.elements],
      ),
      history: [...state.history, _snap(current)],
      future: const [],
      selected: -1,
      formTick: state.formTick + 1,
    ));
  }

  Future<void> pickImage(ImageSlot slot) async {
    try {
      final file = await _picker.pickImage(source: ImageSource.gallery);
      if (file == null || isClosed) return;
      final bytes = await _downscale(await file.readAsBytes());
      if (isClosed) return;
      _applyImage(slot, bytes);
    } catch (_) {
      toast('Could not open the gallery');
    }
  }

  void removeBackground() {
    final current = state.current;
    final index = state.selected;
    if (current == null || index < 0 || index >= current.elements.length) return;
    final element = current.elements[index];
    if (element.kind != ElementKind.image || !element.photo || element.imageBytes != null) return;
    final token = ++_removeToken;
    emit(state.copyWith(
      history: [...state.history, _snap(current)],
      future: const [],
      removingBackground: true,
    ));
    Future<void>.delayed(const Duration(milliseconds: 1600), () {
      if (isClosed || token != _removeToken) return;
      final latest = state.current;
      if (latest == null || index >= latest.elements.length) {
        emit(state.copyWith(removingBackground: false));
        return;
      }
      final target = latest.elements[index];
      if (target.kind != ElementKind.image || !target.photo) {
        emit(state.copyWith(removingBackground: false));
        return;
      }
      final elements = [...latest.elements];
      elements[index] = target.copyWith(photo: false);
      emit(state.copyWith(
        current: latest.copyWith(elements: elements),
        removingBackground: false,
        formTick: state.formTick + 1,
      ));
      toast('Background removed');
    });
  }

  void saveDraft() => _save(DesignStatus.draft);

  Future<void> publish({Uint8List? poster}) async {
    final current = state.current;
    if (current == null || state.publishing) return;
    if (current.name.trim().isEmpty) {
      toast('Add a design name to publish');
      return;
    }
    if (poster == null || poster.isEmpty) {
      toast('Could not create the design image');
      return;
    }
    emit(state.copyWith(publishing: true));
    try {
      final remoteId = await _templates.publish(
        current,
        authorName: state.user?.name ?? 'Creator',
        poster: poster,
      );
      if (isClosed) return;
      _save(DesignStatus.published, remoteId: remoteId);
    } on TemplatePublishException catch (error, stackTrace) {
      debugPrint('Publish failed: $error\n$stackTrace');
      if (isClosed) return;
      emit(state.copyWith(publishing: false));
      toast(error.message);
    } catch (error, stackTrace) {
      debugPrint('Publish failed: $error\n$stackTrace');
      if (isClosed) return;
      emit(state.copyWith(publishing: false));
      toast('Could not publish the design');
    }
  }

  Future<void> togglePublished(int id, {Uint8List? poster}) async {
    if (state.publishing) return;
    final designs = [...state.designs];
    final index = designs.indexWhere((design) => design.id == id);
    if (index < 0) return;
    final design = designs[index];
    if (design.status == DesignStatus.published) {
      designs[index] = design.copyWith(status: DesignStatus.draft);
      emit(state.copyWith(designs: designs, formTick: state.formTick + 1));
      toast('Moved to drafts');
      return;
    }
    if (poster == null || poster.isEmpty) {
      toast('Could not create the design image');
      return;
    }
    emit(state.copyWith(publishing: true));
    try {
      final remoteId = await _templates.publish(
        design,
        authorName: state.user?.name ?? 'Creator',
        poster: poster,
      );
      if (isClosed) return;
      final next = [...state.designs];
      final nextIndex = next.indexWhere((item) => item.id == id);
      if (nextIndex >= 0) {
        next[nextIndex] = next[nextIndex].copyWith(
          status: DesignStatus.published,
          remoteId: remoteId,
        );
      }
      emit(state.copyWith(designs: next, publishing: false, formTick: state.formTick + 1));
      toast('Design published');
    } on TemplatePublishException catch (error, stackTrace) {
      debugPrint('Publish failed: $error\n$stackTrace');
      if (isClosed) return;
      emit(state.copyWith(publishing: false));
      toast(error.message);
    } catch (error, stackTrace) {
      debugPrint('Publish failed: $error\n$stackTrace');
      if (isClosed) return;
      emit(state.copyWith(publishing: false));
      toast('Could not publish the design');
    }
  }

  void deleteDesign(int id) {
    emit(state.copyWith(
      designs: state.designs.where((design) => design.id != id).toList(),
      formTick: state.formTick + 1,
    ));
    toast('Design deleted');
  }

  void toast(String message) {
    emit(state.copyWith(toastMessage: message, toastTick: state.toastTick + 1));
  }

  @override
  Future<void> close() {
    _cancelAsync();
    _templates.close();
    return super.close();
  }

  void _save(String status, {int? remoteId}) {
    var current = state.current;
    if (current == null) return;
    if (status == DesignStatus.published && current.name.trim().isEmpty) {
      toast('Add a design name to publish');
      return;
    }
    if (current.name.trim().isEmpty) {
      current = current.copyWith(name: 'Untitled design');
    }
    final saved = current.copyWith(
      status: status,
      savedAt: _formatDate(DateTime.now()),
      elements: [...current.elements],
      remoteId: remoteId,
    );
    final designs = [...state.designs];
    final editingId = state.editingId;
    final index = editingId == null ? -1 : designs.indexWhere((design) => design.id == editingId);
    final storedId = index < 0 ? saved.id : editingId!;
    final stored = saved.copyWith(id: storedId);
    if (index < 0) {
      designs.insert(0, stored);
    } else {
      designs[index] = stored;
    }
    if (status == DesignStatus.published) {
      emit(state.copyWith(
        designs: designs,
        current: current.copyWith(name: stored.name, remoteId: stored.remoteId),
        editingId: storedId,
        publishedDesign: stored,
        view: StudioView.published,
        publishing: false,
        formTick: state.formTick + 1,
      ));
      toast('Design published');
      return;
    }
    emit(state.copyWith(
      designs: designs,
      current: current.copyWith(name: stored.name),
      editingId: storedId,
      view: StudioView.mine,
      filter: DesignFilter.drafts,
      formTick: state.formTick + 1,
    ));
    toast('Saved as draft — publish it anytime from My designs');
  }

  void _applyImage(ImageSlot slot, Uint8List bytes) {
    final current = state.current;
    if (current == null) return;
    if (slot == ImageSlot.background) {
      emit(state.copyWith(
        current: current.copyWith(backgroundImage: bytes),
        history: [...state.history, _snap(current)],
        future: const [],
        formTick: state.formTick + 1,
      ));
      return;
    }
    if (slot == ImageSlot.main) {
      final index = current.firstImage;
      if (index == null) return;
      final elements = [...current.elements];
      elements[index] = elements[index].copyWith(imageBytes: bytes, emoji: '', photo: false);
      emit(state.copyWith(
        current: current.copyWith(elements: elements),
        history: [...state.history, _snap(current)],
        future: const [],
        formTick: state.formTick + 1,
      ));
      return;
    }
    final selected = state.selected;
    if (selected >= 0 && selected < current.elements.length && current.elements[selected].kind == ElementKind.image) {
      final elements = [...current.elements];
      elements[selected] = elements[selected].copyWith(imageBytes: bytes, emoji: '', photo: false);
      emit(state.copyWith(
        current: current.copyWith(elements: elements),
        history: [...state.history, _snap(current)],
        future: const [],
        formTick: state.formTick + 1,
      ));
      return;
    }
    _add(DesignElement.image(
      x: 25,
      y: 25,
      w: 50,
      emoji: '',
      imageBytes: bytes,
      photo: false,
    ));
  }

  void _setTextRole({required bool first, required String value}) {
    final current = state.current;
    if (current == null) return;
    final indexes = current.textIndexes;
    if (indexes.isEmpty) return;
    if (!first && indexes.length < 2) return;
    final index = first ? indexes.first : indexes.last;
    _armLive(800);
    _writeElement(index, state.current!.elements[index].copyWith(text: value));
  }

  void _writeElement(int index, DesignElement element) {
    final current = state.current;
    if (current == null || index < 0 || index >= current.elements.length) return;
    final elements = [...current.elements];
    elements[index] = element;
    emit(state.copyWith(current: current.copyWith(elements: elements)));
  }

  void _updateSelected(
    DesignElement Function(DesignElement element) change, {
    bool record = true,
    bool form = true,
  }) {
    final current = state.current;
    final index = state.selected;
    if (current == null || index < 0 || index >= current.elements.length) return;
    final elements = [...current.elements];
    elements[index] = change(elements[index]);
    emit(state.copyWith(
      current: current.copyWith(elements: elements),
      history: record ? [...state.history, _snap(current)] : state.history,
      future: record ? const [] : state.future,
      formTick: form ? state.formTick + 1 : state.formTick,
    ));
  }

  void _add(DesignElement element) {
    final current = state.current;
    if (current == null) return;
    final elements = [...current.elements, element];
    emit(state.copyWith(
      current: current.copyWith(elements: elements),
      history: [...state.history, _snap(current)],
      future: const [],
      selected: elements.length - 1,
      formTick: state.formTick + 1,
    ));
  }

  void _armLive(int milliseconds) {
    final current = state.current;
    if (!_live && current != null) {
      _live = true;
      emit(state.copyWith(
        history: [...state.history, _snap(current)],
        future: const [],
      ));
    }
    _liveTimer?.cancel();
    if (milliseconds <= 0) return;
    _liveTimer = Timer(Duration(milliseconds: milliseconds), () => _live = false);
  }

  void _cancelAsync() {
    _removeToken++;
    _liveTimer?.cancel();
    _live = false;
    _gestureBefore = null;
  }

  EditorSnapshot _snap(Design design) {
    return EditorSnapshot(
      bg1: design.bg1,
      bg2: design.bg2,
      backgroundImage: design.backgroundImage,
      elements: [...design.elements],
    );
  }

  Design _restore(Design design, EditorSnapshot snap) {
    return design.copyWith(
      bg1: snap.bg1,
      bg2: snap.bg2,
      backgroundImage: snap.backgroundImage,
      elements: [...snap.elements],
    );
  }

  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  Future<Uint8List> _downscale(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final source = frame.image;
    final maxSide = math.max(source.width, source.height);
    final scale = maxSide == 0 ? 1.0 : math.min(1.0, 900 / maxSide);
    final width = math.max(1, (source.width * scale).round());
    final height = math.max(1, (source.height * scale).round());
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawImageRect(
      source,
      Rect.fromLTWH(0, 0, source.width.toDouble(), source.height.toDouble()),
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      Paint()..filterQuality = FilterQuality.medium,
    );
    final image = await recorder.endRecording().toImage(width, height);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    source.dispose();
    image.dispose();
    return data?.buffer.asUint8List() ?? bytes;
  }
}

enum ImageSlot { selectedOrNew, main, background }
